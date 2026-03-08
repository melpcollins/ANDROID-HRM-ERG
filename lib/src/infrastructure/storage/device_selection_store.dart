import 'package:shared_preferences/shared_preferences.dart';

class DeviceSelectionStore {
  static const String hrMonitorKey = 'selected_hr_monitor_id';
  static const String trainerKey = 'selected_trainer_id';

  Future<void> saveHrMonitorId(String id) => _saveValue(hrMonitorKey, id);

  Future<void> saveTrainerId(String id) => _saveValue(trainerKey, id);

  Future<String?> getHrMonitorId() => _getValue(hrMonitorKey);

  Future<String?> getTrainerId() => _getValue(trainerKey);

  Future<void> _saveValue(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _getValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}
