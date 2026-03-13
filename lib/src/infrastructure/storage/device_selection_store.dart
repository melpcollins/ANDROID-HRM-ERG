import 'package:shared_preferences/shared_preferences.dart';

class DeviceSelectionStore {
  static const String hrMonitorKey = 'selected_hr_monitor_id';
  static const String trainerKey = 'selected_trainer_id';
  static const String hrErgStartingWattsKey = 'hr_erg_starting_watts';
  static const String hrErgTargetHrKey = 'hr_erg_target_hr';

  Future<void> saveHrMonitorId(String id) => _saveValue(hrMonitorKey, id);

  Future<void> saveTrainerId(String id) => _saveValue(trainerKey, id);

  Future<String?> getHrMonitorId() => _getValue(hrMonitorKey);

  Future<String?> getTrainerId() => _getValue(trainerKey);

  Future<void> saveHrErgStartingWatts(int watts) => _saveInt(
    hrErgStartingWattsKey,
    watts,
  );

  Future<void> saveHrErgTargetHr(int bpm) => _saveInt(hrErgTargetHrKey, bpm);

  Future<int?> getHrErgStartingWatts() => _getInt(hrErgStartingWattsKey);

  Future<int?> getHrErgTargetHr() => _getInt(hrErgTargetHrKey);

  Future<void> _saveValue(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _getValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<int?> _getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }
}
