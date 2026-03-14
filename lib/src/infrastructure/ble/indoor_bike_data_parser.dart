import '../../domain/models/trainer_telemetry.dart';

TrainerTelemetry? parseIndoorBikeData(
  List<int> data, {
  required DateTime timestamp,
}) {
  if (data.length < 4) {
    return null;
  }

  final flags = _readUint16(data, 0);
  var index = 2;

  if ((flags & 0x0001) == 0) {
    index = _skip(data, index, 2);
  }
  if ((flags & 0x0002) != 0) {
    index = _skip(data, index, 2);
  }

  int? cadenceRpm;
  if ((flags & 0x0004) != 0) {
    if (!_hasBytes(data, index, 2)) {
      return null;
    }
    final cadenceRaw = _readUint16(data, index);
    cadenceRpm = (cadenceRaw / 2).round();
    index += 2;
  }

  if ((flags & 0x0008) != 0) {
    index = _skip(data, index, 2);
  }
  if ((flags & 0x0010) != 0) {
    index = _skip(data, index, 3);
  }
  if ((flags & 0x0020) != 0) {
    index = _skip(data, index, 2);
  }

  if ((flags & 0x0040) == 0) {
    return null;
  }
  if (!_hasBytes(data, index, 2)) {
    return null;
  }

  final powerWatts = _readSint16(data, index);

  return TrainerTelemetry(
    powerWatts: powerWatts,
    cadenceRpm: cadenceRpm,
    timestamp: timestamp,
  );
}

bool _hasBytes(List<int> data, int index, int length) {
  return index + length <= data.length;
}

int _skip(List<int> data, int index, int length) {
  if (!_hasBytes(data, index, length)) {
    return data.length;
  }
  return index + length;
}

int _readUint16(List<int> data, int index) {
  return data[index] | (data[index + 1] << 8);
}

int _readSint16(List<int> data, int index) {
  final value = _readUint16(data, index);
  return value >= 0x8000 ? value - 0x10000 : value;
}
