import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  const AppInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.operatingSystemVersion,
    required this.phoneModel,
    this.androidApiLevel,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String platform;
  final String operatingSystemVersion;
  final String phoneModel;
  final int? androidApiLevel;

  String get versionLabel => '$version+$buildNumber';

  Map<String, Object?> toTelemetryProperties() {
    return <String, Object?>{
      'app_version': version,
      'build_number': buildNumber,
      if (androidApiLevel != null) 'android_api': androidApiLevel,
      'phone_model': phoneModel,
    };
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'app_name': appName,
      'package_name': packageName,
      'version': version,
      'build_number': buildNumber,
      'platform': platform,
      'operating_system_version': operatingSystemVersion,
      'phone_model': phoneModel,
      'android_api': androidApiLevel,
    };
  }

  static AppInfo placeholder() {
    return const AppInfo(
      appName: 'Cycling HR ERG',
      packageName: 'unknown',
      version: '0.0.0',
      buildNumber: '0',
      platform: 'unknown',
      operatingSystemVersion: 'unknown',
      phoneModel: 'unknown',
    );
  }

  static Future<AppInfo> load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfoPlugin = DeviceInfoPlugin();

    var platform = Platform.operatingSystem;
    var operatingSystemVersion = Platform.operatingSystemVersion;
    var phoneModel = 'unknown';
    int? androidApiLevel;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      platform = 'android';
      operatingSystemVersion = 'Android ${androidInfo.version.release}';
      phoneModel = androidInfo.model;
      androidApiLevel = androidInfo.version.sdkInt;
    }

    return AppInfo(
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      platform: platform,
      operatingSystemVersion: operatingSystemVersion,
      phoneModel: phoneModel,
      androidApiLevel: androidApiLevel,
    );
  }
}
