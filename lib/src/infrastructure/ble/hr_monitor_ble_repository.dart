import 'dart:async';

import '../../domain/models/hr_sample.dart';
import '../../domain/repositories/hr_monitor_repository.dart';
import 'ble_device_repository_base.dart';

class HrMonitorBleRepository extends BleDeviceRepositoryBase
    implements HrMonitorRepository {
  HrMonitorBleRepository({required super.store})
    : _hrController = StreamController<HrSample>.broadcast(),
      super(nameMatcher: _isLikelyHrMonitor);

  final StreamController<HrSample> _hrController;

  @override
  Stream<HrSample> get hrSamples => _hrController.stream;

  @override
  Future<String?> getSavedDeviceId() {
    return selectionStore.getHrMonitorId();
  }

  @override
  Future<void> persistSelectedDeviceId(String id) {
    return selectionStore.saveHrMonitorId(id);
  }

  static bool _isLikelyHrMonitor(String name) {
    final lower = name.toLowerCase();
    return lower.contains('hr') ||
        lower.contains('heart') ||
        lower.contains('polar') ||
        lower.contains('h10') ||
        lower.contains('dual');
  }
}
