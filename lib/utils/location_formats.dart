String formatPlusCode(double lat, double lon) {
  const base = '23456789CFGHJMPQRVWX';

  var normalizedLat = (lat + 90) / 180;
  var normalizedLon = (lon + 180) / 360;

  final buffer = StringBuffer();
  for (var i = 0; i < 8; i++) {
    if (i == 4) {
      buffer.write('+');
    }

    final latDigit = (normalizedLat * 20).floor() % 20;
    final lonDigit = (normalizedLon * 20).floor() % 20;

    buffer
      ..write(base[latDigit])
      ..write(base[lonDigit]);

    normalizedLat = (normalizedLat * 20) % 1;
    normalizedLon = (normalizedLon * 20) % 1;
  }

  return buffer.toString();
}
