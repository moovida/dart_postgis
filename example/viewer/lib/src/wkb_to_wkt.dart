import 'package:dart_postgis/dart_postgis.dart' as pg;

/// Converts a PostGIS EWKB hex string to WKT using dart_postgis BinaryParser.
/// Returns null if [hex] is not a valid WKB hex string.
String? wkbHexToWkt(String? hex) {
  if (hex == null || hex.length < 10 || hex.length % 2 != 0) return null;
  final first = hex.substring(0, 2).toLowerCase();
  if (first != '00' && first != '01') return null;
  if (!_isAllHex(hex)) return null;
  try {
    final bytes = [
      for (int i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16)
    ];
    return pg.BinaryParser().parse(bytes).toText();
  } catch (_) {
    return null;
  }
}

bool _isAllHex(String s) {
  for (final c in s.codeUnits) {
    if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102))) {
      return false;
    }
  }
  return true;
}
