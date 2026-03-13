import 'package:flutter/foundation.dart';

class AppDebugConfig {
  const AppDebugConfig({
    required this.useMockDevices,
  });

  factory AppDebugConfig.fromEnvironment() {
    const useMockDevicesFromEnvironment = bool.fromEnvironment(
      'USE_MOCK_DEVICES',
    );
    return const AppDebugConfig(
      useMockDevices: kDebugMode && useMockDevicesFromEnvironment,
    );
  }

  final bool useMockDevices;
}
