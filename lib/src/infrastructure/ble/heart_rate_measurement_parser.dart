int parseHeartRateMeasurement(List<int> data) {
  if (data.isEmpty) {
    return 0;
  }

  final flags = data[0];
  final is16Bit = (flags & 0x01) != 0;

  if (is16Bit) {
    if (data.length < 3) {
      return 0;
    }
    return data[1] | (data[2] << 8);
  }

  if (data.length < 2) {
    return 0;
  }

  return data[1];
}
