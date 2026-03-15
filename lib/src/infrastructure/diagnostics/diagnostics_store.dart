import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/session_context.dart';
import '../../domain/models/session_diagnostics_record.dart';

class DiagnosticsStore {
  DiagnosticsStore._({
    Directory? rootDirectory,
    int maxSessions = 20,
    int maxRuntimeEvents = 500,
  }) : _rootDirectory = rootDirectory,
       _maxSessions = maxSessions,
       _maxRuntimeEvents = maxRuntimeEvents;

  final Directory? _rootDirectory;
  final int _maxSessions;
  final int _maxRuntimeEvents;
  final List<Map<String, Object?>> _runtimeEventCache =
      <Map<String, Object?>>[];
  final Map<String, SessionDiagnosticsRecord> _sessionCache =
      <String, SessionDiagnosticsRecord>{};
  Future<void> _ioQueue = Future<void>.value();

  bool get isPersistent => _rootDirectory != null;

  String? get rootPath => _rootDirectory?.path;

  static Future<DiagnosticsStore> initialize({
    int maxSessions = 20,
    int maxRuntimeEvents = 500,
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final store = DiagnosticsStore._(
      rootDirectory: Directory(_joinPath(supportDirectory.path, 'diagnostics')),
      maxSessions: maxSessions,
      maxRuntimeEvents: maxRuntimeEvents,
    );
    await store._ensureReady();
    return store;
  }

  factory DiagnosticsStore.inMemory({
    int maxSessions = 20,
    int maxRuntimeEvents = 500,
  }) {
    return DiagnosticsStore._(
      maxSessions: maxSessions,
      maxRuntimeEvents: maxRuntimeEvents,
    );
  }

  factory DiagnosticsStore.forDirectory(
    Directory directory, {
    int maxSessions = 20,
    int maxRuntimeEvents = 500,
  }) {
    return DiagnosticsStore._(
      rootDirectory: Directory(_joinPath(directory.path, 'diagnostics')),
      maxSessions: maxSessions,
      maxRuntimeEvents: maxRuntimeEvents,
    );
  }

  Future<void> ensureReady() => _ensureReady();

  Future<void> recordRuntimeEvent(
    String name, {
    Map<String, Object?> data = const <String, Object?>{},
  }) async {
    final event = <String, Object?>{
      'name': name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': _normalizeMap(data),
    };

    _runtimeEventCache.add(event);
    if (_runtimeEventCache.length > _maxRuntimeEvents) {
      _runtimeEventCache.removeRange(
        0,
        _runtimeEventCache.length - _maxRuntimeEvents,
      );
    }

    final runtimeFile = _runtimeFile;
    if (runtimeFile == null) {
      return;
    }

    await _enqueueIo(() async {
      await runtimeFile.writeAsString(
        '${jsonEncode(event)}\n',
        mode: FileMode.append,
        flush: true,
      );
      await _trimRuntimeFile();
    });
  }

  Future<void> startSession(SessionContext context) async {
    final record = SessionDiagnosticsRecord(context: context);
    _sessionCache[context.sessionId] = record;
    await _persistSession(record);
    await pruneSessions();
  }

  Future<void> recordSessionEvent(
    String sessionId,
    String name, {
    Map<String, Object?> data = const <String, Object?>{},
  }) async {
    final record = await _loadSession(sessionId);
    if (record == null) {
      return;
    }

    final updated = record.copyWith(
      events: <DiagnosticsEvent>[
        ...record.events,
        DiagnosticsEvent(
          name: name,
          timestamp: DateTime.now().toUtc(),
          data: _normalizeMap(data),
        ),
      ],
    );
    _sessionCache[sessionId] = updated;
    await _persistSession(updated);
  }

  Future<void> closeSession({
    required String sessionId,
    required String outcome,
    Map<String, Object?> summary = const <String, Object?>{},
  }) async {
    final record = await _loadSession(sessionId);
    if (record == null) {
      return;
    }

    final updated = record.copyWith(
      endedAt: DateTime.now().toUtc(),
      outcome: outcome,
      summary: _normalizeMap(summary),
    );
    _sessionCache[sessionId] = updated;
    await _persistSession(updated);
    await pruneSessions();
  }

  Future<List<Map<String, Object?>>> recentRuntimeEvents({
    int limit = 200,
  }) async {
    await _waitForPendingIo();
    final runtimeFile = _runtimeFile;
    if (runtimeFile == null || !await runtimeFile.exists()) {
      if (_runtimeEventCache.length <= limit) {
        return List<Map<String, Object?>>.from(_runtimeEventCache);
      }
      return _runtimeEventCache.sublist(_runtimeEventCache.length - limit);
    }

    final events = await _readRuntimeEventsFromFile();
    if (events.length <= limit) {
      return events;
    }
    return events.sublist(events.length - limit);
  }

  Future<List<SessionDiagnosticsRecord>> recentSessions({
    int limit = 20,
  }) async {
    await _waitForPendingIo();
    final sessionsDirectory = _sessionsDirectory;
    if (sessionsDirectory == null || !await sessionsDirectory.exists()) {
      final values = _sessionCache.values.toList()
        ..sort(
          (left, right) =>
              right.context.startedAt.compareTo(left.context.startedAt),
        );
      return values.take(limit).toList();
    }

    final files = await sessionsDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort(
      (left, right) =>
          right.lastModifiedSync().compareTo(left.lastModifiedSync()),
    );

    final records = <SessionDiagnosticsRecord>[];
    for (final file in files.take(limit)) {
      final record = await _readSessionFile(file);
      if (record != null) {
        records.add(record);
      }
    }
    return records;
  }

  Future<File> createExportFile({
    required String fileName,
    required Map<String, Object?> payload,
  }) async {
    if (!isPersistent) {
      final tempFile = File(_joinPath(Directory.systemTemp.path, fileName));
      await _enqueueIo(() async {
        await tempFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(_normalizeMap(payload)),
          flush: true,
        );
      });
      return tempFile;
    }

    final exportsDirectory = _exportsDirectory!;
    if (!await exportsDirectory.exists()) {
      await exportsDirectory.create(recursive: true);
    }
    final file = File(_joinPath(exportsDirectory.path, fileName));
    await _enqueueIo(() async {
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_normalizeMap(payload)),
        flush: true,
      );
    });
    return file;
  }

  Future<void> pruneSessions() async {
    final sessionsDirectory = _sessionsDirectory;
    if (sessionsDirectory == null || !await sessionsDirectory.exists()) {
      if (_sessionCache.length <= _maxSessions) {
        return;
      }
      final sortedKeys = _sessionCache.values.toList()
        ..sort(
          (left, right) =>
              left.context.startedAt.compareTo(right.context.startedAt),
        );
      for (final record in sortedKeys.take(sortedKeys.length - _maxSessions)) {
        _sessionCache.remove(record.context.sessionId);
      }
      return;
    }

    final files = await sessionsDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    if (files.length <= _maxSessions) {
      return;
    }

    files.sort(
      (left, right) =>
          left.lastModifiedSync().compareTo(right.lastModifiedSync()),
    );
    for (final file in files.take(files.length - _maxSessions)) {
      _sessionCache.remove(_sessionIdForPath(file.path));
      await file.delete();
    }
  }

  Future<void> _ensureReady() async {
    if (!isPersistent) {
      return;
    }

    final rootDirectory = _rootDirectory;
    final sessionsDirectory = _sessionsDirectory;
    final exportsDirectory = _exportsDirectory;
    final runtimeFile = _runtimeFile;
    if (rootDirectory == null ||
        sessionsDirectory == null ||
        exportsDirectory == null ||
        runtimeFile == null) {
      return;
    }

    if (!await rootDirectory.exists()) {
      await rootDirectory.create(recursive: true);
    }
    if (!await sessionsDirectory.exists()) {
      await sessionsDirectory.create(recursive: true);
    }
    if (!await exportsDirectory.exists()) {
      await exportsDirectory.create(recursive: true);
    }
    if (!await runtimeFile.exists()) {
      await runtimeFile.create(recursive: true);
    }
    await _trimRuntimeFile();
    await pruneSessions();
  }

  Future<void> _persistSession(SessionDiagnosticsRecord record) async {
    final normalized = _normalizeMap(record.toJson());
    final sessionFile = _sessionFile(record.context.sessionId);
    if (sessionFile == null) {
      return;
    }
    await _enqueueIo(() async {
      await sessionFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(normalized),
        flush: true,
      );
    });
  }

  Future<SessionDiagnosticsRecord?> _loadSession(String sessionId) async {
    await _waitForPendingIo();
    final cached = _sessionCache[sessionId];
    if (cached != null) {
      return cached;
    }

    final sessionFile = _sessionFile(sessionId);
    if (sessionFile == null || !await sessionFile.exists()) {
      return null;
    }

    final record = await _readSessionFile(sessionFile);
    if (record == null) {
      return null;
    }
    _sessionCache[sessionId] = record;
    return record;
  }

  Future<void> _trimRuntimeFile() async {
    final runtimeFile = _runtimeFile;
    if (runtimeFile == null || !await runtimeFile.exists()) {
      return;
    }

    final events = await _readRuntimeEventsFromFile();
    if (events.length <= _maxRuntimeEvents) {
      return;
    }
    final selected = events.sublist(events.length - _maxRuntimeEvents);
    final encoded = selected.map(jsonEncode).join('\n');
    await runtimeFile.writeAsString('$encoded\n', flush: true);
  }

  Future<List<Map<String, Object?>>> _readRuntimeEventsFromFile() async {
    final runtimeFile = _runtimeFile;
    if (runtimeFile == null || !await runtimeFile.exists()) {
      return List<Map<String, Object?>>.from(_runtimeEventCache);
    }

    final lines = await runtimeFile.readAsLines();
    final events = <Map<String, Object?>>[];
    var droppedMalformedLine = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        events.add(jsonDecode(trimmed) as Map<String, Object?>);
      } on FormatException {
        droppedMalformedLine = true;
      }
    }

    if (droppedMalformedLine) {
      await _enqueueIo(() async {
        final encoded = events.map(jsonEncode).join('\n');
        await runtimeFile.writeAsString(
          encoded.isEmpty ? '' : '$encoded\n',
          flush: true,
        );
      });
    }

    return events;
  }

  Directory? get _sessionsDirectory => _rootDirectory == null
      ? null
      : Directory(_joinPath(_rootDirectory.path, 'sessions'));

  Directory? get _exportsDirectory => _rootDirectory == null
      ? null
      : Directory(_joinPath(_rootDirectory.path, 'exports'));

  File? get _runtimeFile => _rootDirectory == null
      ? null
      : File(_joinPath(_rootDirectory.path, 'runtime.jsonl'));

  File? _sessionFile(String sessionId) {
    final sessionsDirectory = _sessionsDirectory;
    if (sessionsDirectory == null) {
      return null;
    }
    return File(_joinPath(sessionsDirectory.path, '$sessionId.json'));
  }

  static String _sessionIdForPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    return fileName.endsWith('.json')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
  }

  Future<void> _enqueueIo(Future<void> Function() action) {
    final next = _ioQueue.then((_) => action());
    _ioQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _waitForPendingIo() async {
    await _ioQueue;
  }

  Future<SessionDiagnosticsRecord?> _readSessionFile(File file) async {
    try {
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return SessionDiagnosticsRecord.fromJson(decoded);
    } on FormatException {
      await _enqueueIo(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });
      return null;
    }
  }
}

Map<String, Object?> _normalizeMap(Map<String, Object?> input) {
  return Map<String, Object?>.fromEntries(
    input.entries.map(
      (entry) => MapEntry(entry.key, _normalizeValue(entry.value)),
    ),
  );
}

Object? _normalizeValue(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  if (value is Enum) {
    return value.name;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Duration) {
    return value.inMilliseconds;
  }
  if (value is Map<Object?, Object?>) {
    return Map<String, Object?>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(entry.key.toString(), _normalizeValue(entry.value)),
      ),
    );
  }
  if (value is Iterable<Object?>) {
    return value.map(_normalizeValue).toList();
  }
  return value.toString();
}

String _joinPath(String left, String right) {
  return '$left${Platform.pathSeparator}$right';
}
