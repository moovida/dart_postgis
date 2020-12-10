part of dart_postgis;

/// All the classes in here have been ported from the
/// PostGIS extension for PostgreSQL JDBC driver project.
///
/// License is LGPL.
///
/// Original authors:
/// (C) 2005 Markus Schaber, markus.schaber@logix-tt.com
/// (C) 2015 Phillip Ross, phillip.w.g.ross@gmail.com
/// Dart port:
/// 2020 Antonello Andrea (www.hydrologis.com)

abstract class ByteGetter {
  /// Get a byte.
  ///
  /// @param index the index to get the value from
  /// @return The result is returned as Int to eliminate sign problems when
  ///         or'ing several values together.
  int get(int index);
}

class BinaryByteGetter extends ByteGetter {
  List<int> array;

  BinaryByteGetter(List<int> array) {
    this.array = array;
  }

  @override
  int get(int index) {
    return array[index] & 0xFF; // mask out sign-extended bits.
  }
}

// class StringByteGetter extends ByteGetter {
//   String rep;

//   StringByteGetter(String rep) {
//     this.rep = rep;
//   }

//   @override
//   int get(int index) {
//     index *= 2;
//     int high = unhex(rep.codeUnitAt(index));
//     int low = unhex(rep.codeUnitAt(index + 1));
//     return (high << 4) + low;
//   }

//   static int unhex(int c) {
//     if (c >= '0' && c <= '9') {
//       return (byte)(c - '0');
//     } else if (c >= 'A' && c <= 'F') {
//       return (byte)(c - 'A' + 10);
//     } else if (c >= 'a' && c <= 'f') {
//       return (byte)(c - 'a' + 10);
//     } else {
//       throw IllegalArgumentException("No valid Hex char " + c);
//     }
//   }
// }

abstract class ValueGetter {
  ByteGetter data;
  int position = 0;
  final int endian;

  ValueGetter(this.data, this.endian);

  /// Get a byte, should be equal for all endians
  ///
  /// @return the byte value
  int getByte() {
    return data.get(position++);
  }

  int getInt() {
    int res = getIntAt(position);
    position += 4;
    return res;
  }

  int getLong() {
    int res = getLongAt(position);
    position += 8;
    return res;
  }

  /// Get a 32-Bit integer
  ///
  /// @param index the index to get the value from
  /// @return the int value
  int getIntAt(int index);

  /// Get a long value. This is not needed directly, but as a nice side-effect
  /// from GetDouble.
  ///
  /// @param index the index to get the value from
  /// @return the long value
  int getLongAt(int index);

  double getDoubleAt(int index);

  /// Get a double.
  ///
  /// @return the double value
  double getDouble() {
    double res = getDoubleAt(position);
    position += 8;
    return res;

    // int bitrep = getLong();

    // return Double.longBitsToDouble(bitrep);
  }
}

/// Big endian
class XDRGetter extends ValueGetter {
  static final int NUMBER = 0;

  XDRGetter(ByteGetter data) : super(data, NUMBER);

  @override
  int getIntAt(int index) {
    return (data.get(index) << 24) +
        (data.get(index + 1) << 16) +
        (data.get(index + 2) << 8) +
        data.get(index + 3);
  }

  @override
  int getLongAt(int index) {
    return (data.get(index) << 56) +
        (data.get(index + 1) << 48) +
        (data.get(index + 2) << 40) +
        (data.get(index + 3) << 32) +
        (data.get(index + 4) << 24) +
        (data.get(index + 5) << 16) +
        (data.get(index + 6) << 8) +
        (data.get(index + 7) << 0);
  }

  @override
  double getDoubleAt(int index) {
    double value = ByteConversionUtilities.getDouble64(
        Uint8List.fromList([
          data.get(index),
          data.get(index + 1),
          data.get(index + 2),
          data.get(index + 3),
          data.get(index + 4),
          data.get(index + 5),
          data.get(index + 6),
          data.get(index + 7),
        ]),
        Endian.big);
    return value;
  }
}

/// Little endian
class NDRGetter extends ValueGetter {
  static final int NUMBER = 1;

  NDRGetter(ByteGetter data) : super(data, NUMBER);

  @override
  int getIntAt(int index) {
    return (data.get(index + 3) << 24) +
        (data.get(index + 2) << 16) +
        (data.get(index + 1) << 8) +
        data.get(index);
  }

  @override
  int getLongAt(int index) {
    return (data.get(index + 7) << 56) +
        (data.get(index + 6) << 48) +
        (data.get(index + 5) << 40) +
        (data.get(index + 4) << 32) +
        (data.get(index + 3) << 24) +
        (data.get(index + 2) << 16) +
        (data.get(index + 1) << 8) +
        (data.get(index) << 0);
  }

  @override
  double getDoubleAt(int index) {
    double value = ByteConversionUtilities.getDouble64(
        Uint8List.fromList([
          data.get(index),
          data.get(index + 1),
          data.get(index + 2),
          data.get(index + 3),
          data.get(index + 4),
          data.get(index + 5),
          data.get(index + 6),
          data.get(index + 7),
        ]),
        Endian.little);
    return value;
  }
}

/// Parse binary representation of geometries.
///
/// It should be easy to add char[] and CharSequence ByteGetter instances,
/// although the latter one is not compatible with older jdks.
///
/// I did not implement real unsigned 32-bit integers or emulate them with long,
/// as both java Arrays and Strings currently can have only 2^31-1 elements
/// (bytes), so we cannot even get or build Geometries with more than approx.
/// 2^28 coordinates (8 bytes each).
///
/// @author {@literal Markus Schaber <markus.schaber@logix-tt.com>}
///
class BinaryParser {
  static final int UNKNOWN_SRID = 0;

  GeometryFactory gf = GeometryFactory.defaultPrecision();

  /// Get the appropriate ValueGetter for my endianness
  ///
  /// @param bytes The appropriate Byte Getter
  ///
  /// @return the ValueGetter
  static ValueGetter valueGetterForEndian(ByteGetter bytes) {
    if (bytes.get(0) == XDRGetter.NUMBER) {
      // XDR
      return XDRGetter(bytes);
    } else if (bytes.get(0) == NDRGetter.NUMBER) {
      return NDRGetter(bytes);
    } else {
      throw ArgumentError("Unknown Endian type: ${bytes.get(0)}");
    }
  }

  /// Parse a hex encoded geometry
  ///
  /// Is synchronized to protect offset counter. (Unfortunately, Java does not
  /// have neither call by reference nor multiple return values.)
  ///
  /// @param value String containing the data to be parsed
  /// @return resulting geometry for the parsed data
  /// TODO
  //  Geometry parseString(String value) {
  //     StringByteGetter bytes = new StringByteGetter(value);
  //     return parseGeometry(valueGetterForEndian(bytes));
  // }

  /// Parse a binary encoded geometry.
  ///
  /// Is synchronized to protect offset counter. (Unfortunately, Java does not
  /// have neither call by reference nor multiple return values.)
  ///
  /// @param value byte array containing the data to be parsed
  /// @return resulting geometry for the parsed data
  Geometry parse(List<int> value) {
    BinaryByteGetter bytes = BinaryByteGetter(value);
    return parseGeometry(valueGetterForEndian(bytes));
  }

  /// Parse a geometry starting at offset.
  ///
  /// @param data ValueGetter with the data to be parsed
  /// @return the parsed geometry
  /// */
  Geometry parseGeometry(ValueGetter data) {
    int endian = data.getByte(); // skip and test endian flag
    if (endian != data.endian) {
      throw ArgumentError("Endian inconsistency!");
    }
    int typeword = data.getInt();

    int realtype = typeword & 0x1FFFFFFF; // cut off high flag bits
    EGeometryType geometryType = EGeometryType.fromGeometryTypeCode(realtype);

    bool haveZ = (typeword & 0x80000000) != 0;
    bool haveM = (typeword & 0x40000000) != 0;
    bool haveS = (typeword & 0x20000000) != 0;

    int srid = -1;

    if (haveS) {
      srid = data.getInt();
      if (srid < 0) {
        srid = UNKNOWN_SRID;
      }
    }
    Geometry result1;
    switch (geometryType) {
      case EGeometryType.POINT:
        result1 = gf.createPoint(parsePoint(data, haveZ, haveM));
        break;
      case EGeometryType.LINESTRING:
        result1 = parseLineString(data, haveZ, haveM);
        break;
      case EGeometryType.POLYGON:
        result1 = parsePolygon(data, haveZ, haveM);
        break;
      case EGeometryType.MULTIPOINT:
        result1 = parseMultiPoint(data);
        break;
      case EGeometryType.MULTILINESTRING:
        result1 = parseMultiLineString(data);
        break;
      case EGeometryType.MULTIPOLYGON:
        result1 = parseMultiPolygon(data);
        break;
      case EGeometryType.GEOMETRYCOLLECTION:
        result1 = parseCollection(data);
        break;
      default:
        throw ArgumentError("Unknown Geometry Type: $realtype");
    }

    Geometry result = result1;

    if (srid != UNKNOWN_SRID) {
      result.setSRID(srid);
    }
    return result;
  }

  Coordinate parsePoint(ValueGetter data, bool haveZ, bool haveM) {
    double X = data.getDouble();
    double Y = data.getDouble();
    Coordinate result;
    if (haveZ) {
      double Z = data.getDouble();
      result = Coordinate.fromXYZ(X, Y, Z);
    } else {
      result = Coordinate(X, Y);
    }

    if (haveM) {
      result.setM(data.getDouble());
    }

    return result;
  }

  /// Parse an Array of "full" Geometries */
  void parseGeometryArray(ValueGetter data, List<Geometry> container) {
    for (int i = 0; i < container.length; i++) {
      container[i] = parseGeometry(data);
    }
  }

  /// Parse an Array of "slim" Points (without endianness and type, part of
  /// LinearRing and Linestring, but not MultiPoint!
  ///
  /// @param haveZ
  /// @param haveM
  List<Coordinate> parsePointArray(ValueGetter data, bool haveZ, bool haveM) {
    int count = data.getInt();
    List<Coordinate> result = List(count);
    for (int i = 0; i < count; i++) {
      result[i] = parsePoint(data, haveZ, haveM);
    }
    return result;
  }

  MultiPoint parseMultiPoint(ValueGetter data) {
    List<Point> points = List(data.getInt());
    parseGeometryArray(data, points);
    return gf.createMultiPoint(points);
  }

  LineString parseLineString(ValueGetter data, bool haveZ, bool haveM) {
    List<Coordinate> coordinates = parsePointArray(data, haveZ, haveM);
    return gf.createLineString(coordinates);
  }

  LinearRing parseLinearRing(ValueGetter data, bool haveZ, bool haveM) {
    List<Coordinate> coordinates = parsePointArray(data, haveZ, haveM);
    return gf.createLinearRing(coordinates);
  }

  Polygon parsePolygon(ValueGetter data, bool haveZ, bool haveM) {
    int count = data.getInt();
    List<LinearRing> rings = List(count);
    for (int i = 0; i < count; i++) {
      rings[i] = parseLinearRing(data, haveZ, haveM);
    }
    return gf.createPolygon(rings[0], rings.sublist(1));
  }

  MultiLineString parseMultiLineString(ValueGetter data) {
    int count = data.getInt();
    List<LineString> strings = List(count);
    parseGeometryArray(data, strings);
    return gf.createMultiLineString(strings);
  }

  MultiPolygon parseMultiPolygon(ValueGetter data) {
    int count = data.getInt();
    List<Polygon> polys = List(count);
    parseGeometryArray(data, polys);
    return gf.createMultiPolygon(polys);
  }

  GeometryCollection parseCollection(ValueGetter data) {
    int count = data.getInt();
    List<Geometry> geoms = List(count);
    parseGeometryArray(data, geoms);
    return gf.createGeometryCollection(geoms);
  }
}
