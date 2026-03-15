import '../app/app_info.dart';
import '../../domain/models/session_context.dart';

abstract class AppTelemetry {
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const <String, Object?>{},
  });

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String reason = 'unhandled_error',
    bool fatal = false,
    Map<String, Object?> properties = const <String, Object?>{},
  });

  void setSessionContext(SessionContext context);

  void clearSessionContext();
}

class NoopAppTelemetry implements AppTelemetry {
  NoopAppTelemetry({required this.appInfo});

  final AppInfo appInfo;

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String reason = 'unhandled_error',
    bool fatal = false,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {}

  @override
  void clearSessionContext() {}

  @override
  void setSessionContext(SessionContext context) {}
}

Map<String, Object> normalizeTelemetryProperties(Map<String, Object?> raw) {
  final normalized = <String, Object>{};
  for (final entry in raw.entries) {
    final value = _normalizeTelemetryValue(entry.value);
    if (value != null) {
      normalized[entry.key] = value;
    }
  }
  return normalized;
}

String normalizeTelemetryEventName(String event) {
  final sanitized = event
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final withPrefix = sanitized.isEmpty
      ? 'app_event'
      : (RegExp(r'^[a-z]').hasMatch(sanitized) ? sanitized : 'e_$sanitized');
  return withPrefix.length <= 40 ? withPrefix : withPrefix.substring(0, 40);
}

Object? _normalizeTelemetryValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is bool || value is num || value is String) {
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
  return value.toString();
}
