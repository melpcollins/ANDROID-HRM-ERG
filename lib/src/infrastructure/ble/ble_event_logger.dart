import 'dart:developer' as developer;

void logBleEvent(String event, {Map<String, Object?> details = const {}}) {
  final detailText = details.entries
      .where((entry) => entry.value != null)
      .map((entry) => '${entry.key}=${entry.value}')
      .join(', ');

  developer.log(
    detailText.isEmpty ? event : '$event [$detailText]',
    name: 'android_hrm_erg.ble',
  );
}
