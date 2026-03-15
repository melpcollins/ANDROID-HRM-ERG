import 'package:equatable/equatable.dart';

import 'session_context.dart';

class DiagnosticsEvent extends Equatable {
  const DiagnosticsEvent({
    required this.name,
    required this.timestamp,
    this.data = const <String, Object?>{},
  });

  final String name;
  final DateTime timestamp;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'data': data,
    };
  }

  factory DiagnosticsEvent.fromJson(Map<String, Object?> json) {
    return DiagnosticsEvent(
      name: json['name'] as String? ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] as String? ??
            DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
      ),
      data: Map<String, Object?>.from(
        (json['data'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
            .map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }

  @override
  List<Object?> get props => [name, timestamp, data];
}

class SessionDiagnosticsRecord extends Equatable {
  const SessionDiagnosticsRecord({
    required this.context,
    this.events = const <DiagnosticsEvent>[],
    this.endedAt,
    this.outcome,
    this.summary = const <String, Object?>{},
  });

  final SessionContext context;
  final List<DiagnosticsEvent> events;
  final DateTime? endedAt;
  final String? outcome;
  final Map<String, Object?> summary;

  SessionDiagnosticsRecord copyWith({
    SessionContext? context,
    List<DiagnosticsEvent>? events,
    DateTime? endedAt,
    String? outcome,
    Map<String, Object?>? summary,
  }) {
    return SessionDiagnosticsRecord(
      context: context ?? this.context,
      events: events ?? this.events,
      endedAt: endedAt ?? this.endedAt,
      outcome: outcome ?? this.outcome,
      summary: summary ?? this.summary,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'context': context.toJson(),
      'events': events.map((event) => event.toJson()).toList(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'outcome': outcome,
      'summary': summary,
    };
  }

  factory SessionDiagnosticsRecord.fromJson(Map<String, Object?> json) {
    return SessionDiagnosticsRecord(
      context: SessionContext.fromJson(
        Map<String, Object?>.from(
          (json['context'] as Map<Object?, Object?>? ??
                  const <Object?, Object?>{})
              .map((key, value) => MapEntry(key.toString(), value)),
        ),
      ),
      events: ((json['events'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map(
            (event) => DiagnosticsEvent.fromJson(
              Map<String, Object?>.from(
                event.map((key, value) => MapEntry(key.toString(), value)),
              ),
            ),
          )
          .toList()),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      outcome: json['outcome'] as String?,
      summary: Map<String, Object?>.from(
        (json['summary'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }

  @override
  List<Object?> get props => [context, events, endedAt, outcome, summary];
}
