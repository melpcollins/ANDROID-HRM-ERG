import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../domain/models/session_context.dart';
import '../app/app_info.dart';
import 'app_telemetry.dart';

class FirebaseAppTelemetry implements AppTelemetry {
  FirebaseAppTelemetry({
    required AppInfo appInfo,
    required FirebaseAnalytics analytics,
    required FirebaseCrashlytics crashlytics,
  }) : _appInfo = appInfo,
       _analytics = analytics,
       _crashlytics = crashlytics;

  final AppInfo _appInfo;
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;
  SessionContext? _sessionContext;

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    await _analytics.logEvent(
      name: normalizeTelemetryEventName(event),
      parameters: normalizeAnalyticsParameters(_mergedProperties(properties)),
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
    final merged = _mergedProperties(properties);
    for (final entry in merged.entries) {
      await _crashlytics.setCustomKey(entry.key, entry.value.toString());
    }
    await _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  @override
  void clearSessionContext() {
    _sessionContext = null;
  }

  @override
  void setSessionContext(SessionContext context) {
    _sessionContext = context;
  }

  Map<String, Object> _mergedProperties(Map<String, Object?> properties) {
    return normalizeTelemetryProperties(<String, Object?>{
      ..._appInfo.toTelemetryProperties(),
      ...?_sessionContext?.toTelemetryProperties(),
      ...properties,
    });
  }
}
