import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../app/app_info.dart';
import 'app_telemetry.dart';
import 'firebase_app_telemetry.dart';

Future<AppTelemetry> createAppTelemetry({required AppInfo appInfo}) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    return FirebaseAppTelemetry(
      appInfo: appInfo,
      analytics: FirebaseAnalytics.instance,
      crashlytics: FirebaseCrashlytics.instance,
    );
  } catch (error, stackTrace) {
    developer.log(
      'Firebase unavailable; falling back to local diagnostics only.',
      name: 'android_hrm_erg.telemetry',
      error: error,
      stackTrace: stackTrace,
    );
    return NoopAppTelemetry(appInfo: appInfo);
  }
}
