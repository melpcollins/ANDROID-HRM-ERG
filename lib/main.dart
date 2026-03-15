import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/app/providers.dart';
import 'src/infrastructure/app/app_info.dart';
import 'src/infrastructure/diagnostics/diagnostics_store.dart';
import 'src/infrastructure/observability/app_telemetry.dart';
import 'src/infrastructure/observability/app_telemetry_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var appInfo = AppInfo.placeholder();
  var diagnosticsStore = DiagnosticsStore.inMemory();
  AppTelemetry telemetry = NoopAppTelemetry(appInfo: appInfo);

  try {
    appInfo = await AppInfo.load();
  } catch (error, stackTrace) {
    developer.log(
      'Unable to load app info; continuing with placeholders.',
      name: 'android_hrm_erg.bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }

  try {
    diagnosticsStore = await DiagnosticsStore.initialize();
  } catch (error, stackTrace) {
    developer.log(
      'Unable to initialize persistent diagnostics store; using in-memory fallback.',
      name: 'android_hrm_erg.bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }

  try {
    telemetry = await createAppTelemetry(appInfo: appInfo);
  } catch (error, stackTrace) {
    developer.log(
      'Unable to initialize telemetry; using no-op fallback.',
      name: 'android_hrm_erg.bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
    telemetry = NoopAppTelemetry(appInfo: appInfo);
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      diagnosticsStore.recordRuntimeEvent(
        'framework_error',
        data: <String, Object?>{
          'error': details.exceptionAsString(),
          'library': details.library,
        },
      ),
    );
    unawaited(
      telemetry.recordError(
        Exception('framework_error'),
        details.stack ?? StackTrace.current,
        reason: 'framework_error',
        fatal: true,
        properties: <String, Object?>{
          'error_type': details.exception.runtimeType.toString(),
        },
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      diagnosticsStore.recordRuntimeEvent(
        'platform_error',
        data: <String, Object?>{'error': error.toString()},
      ),
    );
    unawaited(
      telemetry.recordError(
        Exception('platform_error'),
        stackTrace,
        reason: 'platform_error',
        fatal: true,
        properties: <String, Object?>{
          'error_type': error.runtimeType.toString(),
        },
      ),
    );
    return true;
  };

  await diagnosticsStore.recordRuntimeEvent(
    'app_started',
    data: appInfo.toJson(),
  );

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: <Override>[
            appInfoProvider.overrideWithValue(appInfo),
            diagnosticsStoreProvider.overrideWithValue(diagnosticsStore),
            appTelemetryProvider.overrideWithValue(telemetry),
          ],
          child: const HrmErgApp(),
        ),
      );
    },
    (error, stackTrace) {
      unawaited(
        diagnosticsStore.recordRuntimeEvent(
          'zone_error',
          data: <String, Object?>{'error': error.toString()},
        ),
      );
      unawaited(
        telemetry.recordError(
          Exception('zone_error'),
          stackTrace,
          reason: 'zone_error',
          fatal: true,
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
    },
  );
}
