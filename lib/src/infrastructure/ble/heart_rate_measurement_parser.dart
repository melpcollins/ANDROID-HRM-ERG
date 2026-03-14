class HeartRateMeasurement {
  const HeartRateMeasurement({
    required this.bpm,
    required this.contactSupported,
    required this.contactDetected,
  });

  final int bpm;
  final bool contactSupported;
  final bool? contactDetected;
}

HeartRateMeasurement parseHeartRateMeasurementPacket(List<int> data) {
  if (data.isEmpty) {
    return const HeartRateMeasurement(
      bpm: 0,
      contactSupported: false,
      contactDetected: null,
    );
  }

  final flags = data[0];
  final is16Bit = (flags & 0x01) != 0;
  final contactBits = (flags >> 1) & 0x03;
  final contactSupported = (contactBits & 0x02) != 0;
  final bool? contactDetected = switch (contactBits) {
    0x02 => false,
    0x03 => true,
    _ => null,
  };

  final int bpm;
  if (is16Bit) {
    if (data.length < 3) {
      return HeartRateMeasurement(
        bpm: 0,
        contactSupported: contactSupported,
        contactDetected: contactDetected,
      );
    }
    bpm = data[1] | (data[2] << 8);
  } else {
    if (data.length < 2) {
      return HeartRateMeasurement(
        bpm: 0,
        contactSupported: contactSupported,
        contactDetected: contactDetected,
      );
    }
    bpm = data[1];
  }

  return HeartRateMeasurement(
    bpm: bpm,
    contactSupported: contactSupported,
    contactDetected: contactDetected,
  );
}

int parseHeartRateMeasurement(List<int> data) {
  return parseHeartRateMeasurementPacket(data).bpm;
}
