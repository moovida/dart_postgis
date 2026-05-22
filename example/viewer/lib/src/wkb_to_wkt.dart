import 'dart:typed_data';
import 'package:dart_postgis/dart_postgis.dart' as pg;

/// Converts a raw geometry value from PostgreSQL to WKT.
///
/// Handles three cases:
///  - Already a WKT string (e.g. result of ST_AsText) — returned as-is.
///  - Binary [Uint8List] EWKB (extended query protocol for unknown OIDs).
///  - Hex-encoded EWKB [String] (simple query / text protocol).
///
/// Returns null if [raw] is not recognisable as geometry.
String? wkbToWkt(dynamic raw) {
  if (raw == null) return null;

  // Already a WKT string (produced by ST_AsText on the server side)
  if (raw is String) {
    final trimmed = raw.trimLeft();
    if (_isWktPrefix(trimmed)) return raw;
  }

  try {
    late List<int> bytes;
    if (raw is Uint8List) {
      if (raw.isEmpty || (raw[0] != 0 && raw[0] != 1)) return null;
      bytes = raw;
    } else {
      final s = raw.toString();
      if (s.length < 10 || s.length % 2 != 0) return null;
      final first = s.substring(0, 2).toLowerCase();
      if (first != '00' && first != '01') return null;
      if (!_isAllHex(s)) return null;
      bytes = [
        for (int i = 0; i < s.length; i += 2)
          int.parse(s.substring(i, i + 2), radix: 16)
      ];
    }
    return pg.BinaryParser().parse(bytes).toText();
  } catch (_) {
    return null;
  }
}

final _wktPrefixRe = RegExp(
    r'^(POINT|LINESTRING|POLYGON|MULTIPOINT|MULTILINESTRING|MULTIPOLYGON|GEOMETRYCOLLECTION)',
    caseSensitive: false);

bool _isWktPrefix(String s) => _wktPrefixRe.hasMatch(s);

bool _isAllHex(String s) {
  for (final c in s.codeUnits) {
    if (!((c >= 48 && c <= 57) ||
        (c >= 65 && c <= 70) ||
        (c >= 97 && c <= 102))) {
      return false;
    }
  }
  return true;
}
