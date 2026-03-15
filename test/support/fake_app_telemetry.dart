import 'package:android_hrm_erg/src/domain/models/session_context.dart';
import 'package:android_hrm_erg/src/infrastructure/observability/app_telemetry.dart';

class TrackedTelemetryEvent {
  const TrackedTelemetryEvent({required this.name, required this.properties});

  final String name;
  final Map<String, Object?> properties;
}

class RecordedTelemetryError {
  const RecordedTelemetryError({
    required this.error,
    required this.stackTrace,
    required this.reason,
    required this.fatal,
    required this.properties,
  });

  final Object error;
  final StackTrace stackTrace;
  final String reason;
  final bool fatal;
  final Map<String, Object?> properties;
}

class FakeAppTelemetry implements AppTelemetry {
  final List<TrackedTelemetryEvent> trackedEvents = <TrackedTelemetryEvent>[];
  final List<RecordedTelemetryError> recordedErrors =
      <RecordedTelemetryError>[];
  SessionContext? currentSessionContext;

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    trackedEvents.add(
      TrackedTelemetryEvent(name: event, properties: properties),
    );
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String reason = 'unhandled_error',
    bool fatal = false,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    recordedErrors.add(
      RecordedTelemetryError(
        error: error,
        stackTrace: stackTrace,
        reason: reason,
        fatal: fatal,
        properties: properties,
      ),
    );
  }

  @override
  void clearSessionContext() {
    currentSessionContext = null;
  }

  @override
  void setSessionContext(SessionContext context) {
    currentSessionContext = context;
  }
}
