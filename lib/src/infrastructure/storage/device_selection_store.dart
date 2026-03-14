import 'package:shared_preferences/shared_preferences.dart';

class DeviceSelectionStore {
  static const String hrMonitorKey = 'selected_hr_monitor_id';
  static const String trainerKey = 'selected_trainer_id';
  static const String hrMonitorNameKey = 'selected_hr_monitor_name';
  static const String trainerNameKey = 'selected_trainer_name';
  static const String selectedWorkoutTypeKey = 'selected_workout_type';
  static const String hrErgStartingWattsKey = 'hr_erg_starting_watts';
  static const String hrErgTargetHrKey = 'hr_erg_target_hr';
  static const String hrErgDurationHoursKey = 'hr_erg_duration_hours';
  static const String hrErgDurationMinutesKey = 'hr_erg_duration_minutes';
  static const String powerErgTargetPowerKey = 'power_erg_target_power';
  static const String powerErgMaxHrKey = 'power_erg_max_hr';
  static const String powerErgDurationHoursKey = 'power_erg_duration_hours';
  static const String powerErgDurationMinutesKey = 'power_erg_duration_minutes';
  static const String assessmentPowerKey = 'assessment_power';

  Future<void> saveHrMonitorId(String id) => _saveValue(hrMonitorKey, id);

  Future<void> saveTrainerId(String id) => _saveValue(trainerKey, id);

  Future<void> saveHrMonitorName(String name) =>
      _saveValue(hrMonitorNameKey, name);

  Future<void> saveTrainerName(String name) => _saveValue(trainerNameKey, name);

  Future<String?> getHrMonitorId() => _getValue(hrMonitorKey);

  Future<String?> getTrainerId() => _getValue(trainerKey);

  Future<String?> getHrMonitorName() => _getValue(hrMonitorNameKey);

  Future<String?> getTrainerName() => _getValue(trainerNameKey);

  Future<void> saveSelectedWorkoutType(String type) =>
      _saveValue(selectedWorkoutTypeKey, type);

  Future<String?> getSelectedWorkoutType() => _getValue(selectedWorkoutTypeKey);

  Future<void> saveHrErgStartingWatts(int watts) =>
      _saveInt(hrErgStartingWattsKey, watts);

  Future<void> saveHrErgTargetHr(int bpm) => _saveInt(hrErgTargetHrKey, bpm);

  Future<int?> getHrErgStartingWatts() => _getInt(hrErgStartingWattsKey);

  Future<int?> getHrErgTargetHr() => _getInt(hrErgTargetHrKey);

  Future<void> saveHrErgDurationHours(int hours) =>
      _saveInt(hrErgDurationHoursKey, hours);

  Future<void> saveHrErgDurationMinutes(int minutes) =>
      _saveInt(hrErgDurationMinutesKey, minutes);

  Future<int?> getHrErgDurationHours() => _getInt(hrErgDurationHoursKey);

  Future<int?> getHrErgDurationMinutes() => _getInt(hrErgDurationMinutesKey);

  Future<void> savePowerErgTargetPower(int watts) =>
      _saveInt(powerErgTargetPowerKey, watts);

  Future<void> savePowerErgMaxHr(int bpm) => _saveInt(powerErgMaxHrKey, bpm);

  Future<void> savePowerErgDurationHours(int hours) =>
      _saveInt(powerErgDurationHoursKey, hours);

  Future<void> savePowerErgDurationMinutes(int minutes) =>
      _saveInt(powerErgDurationMinutesKey, minutes);

  Future<int?> getPowerErgTargetPower() => _getInt(powerErgTargetPowerKey);

  Future<int?> getPowerErgMaxHr() => _getInt(powerErgMaxHrKey);

  Future<int?> getPowerErgDurationHours() => _getInt(powerErgDurationHoursKey);

  Future<int?> getPowerErgDurationMinutes() =>
      _getInt(powerErgDurationMinutesKey);

  Future<void> saveAssessmentPower(int watts) =>
      _saveInt(assessmentPowerKey, watts);

  Future<int?> getAssessmentPower() => _getInt(assessmentPowerKey);

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
