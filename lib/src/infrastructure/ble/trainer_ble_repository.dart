import 'dart:async';

import '../../domain/repositories/trainer_repository.dart';
import 'ble_device_repository_base.dart';

class TrainerBleRepository extends BleDeviceRepositoryBase
    implements TrainerRepository {
  TrainerBleRepository({required super.store})
    : _powerController = StreamController<int>.broadcast(),
      super(nameMatcher: _isLikelyTrainer);

  final StreamController<int> _powerController;
  int _currentPower = 0;

  @override
  Stream<int> get currentPower async* {
    yield _currentPower;
    yield* _powerController.stream;
  }

  @override
  Future<void> setTargetPower(int watts) async {
    _currentPower = watts;
    _powerController.add(_currentPower);
  }

  @override
  Future<String?> getSavedDeviceId() {
    return selectionStore.getTrainerId();
  }

  @override
  Future<void> persistSelectedDeviceId(String id) {
    return selectionStore.saveTrainerId(id);
  }

  static bool _isLikelyTrainer(String name) {
    final lower = name.toLowerCase();
    return lower.contains('wattbike') ||
        lower.contains('atom') ||
        lower.contains('trainer') ||
        lower.contains('bike');
  }
}
