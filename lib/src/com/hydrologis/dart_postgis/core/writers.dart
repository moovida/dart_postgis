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
abstract class ByteSetter {
  /// Set a byte.
  ///
  /// @param b byte value to set with
  /// @param index index to set
  void set(int b, int index);
}

class BinaryByteSetter extends ByteSetter {
  List<int> array;

  BinaryByteSetter(int length) {
    array = List(length);
  }

  @override
  void set(int b, int index) {
    array[index] = b; // mask out sign-extended bits.
  }

  List<int> result() {
    return array;
  }

  @override
  String toString() {
    List<int> arr = List(array.length);
    for (int i = 0; i < array.length; i++) {
      arr[i] = array[i] & 0xFF;
    }
    return String.fromCharCodes(arr);
  }
}

class StringByteSetter extends ByteSetter {
  static final List<int> hextypes = "0123456789ABCDEF".codeUnits;
  final List<int> rep;

  StringByteSetter(int length) : rep = List(length * 2);

  @override
  void set(int b, int index) {
    index *= 2;
    rep[index] = hextypes[(b >> 4) & 0xF];
    // rep[index] = hextypes[(b >>> 4) & 0xF];
    rep[index + 1] = hextypes[b & 0xF];
  }

  List<int> resultAsArray() {
    return rep;
  }

  String result() {
    return String.fromCharCodes(rep);
  }

  @override
  String toString() {
    return String.fromCharCodes(rep);
  }
}

abstract class ValueSetter {
  ByteSetter data;
  int position = 0;
  final int endian;

  ValueSetter(this.data, this.endian);

  /// Set a byte, should be equal for all endians
  ///
  /// @param value byte value to be set with.
  void setByte(int value) {
    data.set(value, position);
    position += 1;
  }

  void setInt(int value) {
    setIntAt(value, position);
    position += 4;
  }

  void setLong(int value) {
    setLongAt(value, position);
    position += 8;
  }

  void setDouble(double value) {
    setDoubleAt(value, position);
    position += 8;
  }

  /// Set a 32-Bit integer
  ///
  /// @param value int value to be set with
  /// @param index int value for the index
  ///
  void setIntAt(int value, int index);

  /// Set a long value. This is not needed directly, but as a nice side-effect
  /// from GetDouble.
  ///
  /// @param data int value to be set with
  /// @param index int value for the index
  void setLongAt(int data, int index);

  void setDoubleAt(double data, int index);

  //  String toString() {
  //     String name = getClass().getName();
  //     int pointpos = name.lastIndexOf('.');
  //     String klsName = name.substring(pointpos+1);
  //     return klsName+"('"+(data==null?"NULL":data.toString()+"')");
  // }

}

/// Big endian
class XDRSetter extends ValueSetter {
  static final int NUMBER = 0;

  XDRSetter(ByteSetter data) : super(data, NUMBER);

  @override
  void setIntAt(int value, int index) {
    var bytes = ByteConversionUtilities.bytesFromInt32(value,
        endian: Endian.big, doSigned: true);
    data.set(bytes[0], index);
    data.set(bytes[1], index + 1);
    data.set(bytes[2], index + 2);
    data.set(bytes[3], index + 3);
  }

  @override
  void setLongAt(int value, int index) {
    var bytes = ByteConversionUtilities.bytesFromInt64(value,
        endian: Endian.big, doSigned: true);
    data.set(bytes[0], index);
    data.set(bytes[1], index + 1);
    data.set(bytes[2], index + 2);
    data.set(bytes[3], index + 3);
    data.set(bytes[4], index + 4);
    data.set(bytes[5], index + 5);
    data.set(bytes[6], index + 6);
    data.set(bytes[7], index + 7);
  }

  @override
  void setDoubleAt(double value, int index) {
    var bytes = ByteConversionUtilities.bytesFromDouble64(value,
        endian: Endian.big, doSigned: true);
    data.set(bytes[0], index);
    data.set(bytes[1], index + 1);
    data.set(bytes[2], index + 2);
    data.set(bytes[3], index + 3);
    data.set(bytes[4], index + 4);
    data.set(bytes[5], index + 5);
    data.set(bytes[6], index + 6);
    data.set(bytes[7], index + 7);
  }
}

/// Little endian
class NDRSetter extends ValueSetter {
  static final int NUMBER = 1;

  NDRSetter(ByteSetter data) : super(data, NUMBER);

  @override
  void setIntAt(int value, int index) {
    var bytes = ByteConversionUtilities.bytesFromInt32(value,
        endian: Endian.little, doSigned: true);
    data.set(bytes[0], index);
    data.set(bytes[1], index + 1);
    data.set(bytes[2], index + 2);
    data.set(bytes[3], index + 3);
    // data.set( (value >>> 24), index + 3);
    // data.set( (value >>> 16), index + 2);
    // data.set( (value >>> 8), index + 1);
    // data.set( value, index);
  }

  @override
  void setLongAt(int value, int index) {
    var bytes = ByteConversionUtilities.bytesFromInt64(value,
        endian: Endian.little, doSigned: true);
    data.set(bytes[0], index);
    data.set(bytes[1], index + 1);
    data.set(bytes[2], index + 2);
    data.set(bytes[3], index + 3);
    data.set(bytes[4], index + 4);
    data.set(bytes[5], index + 5);
    data.set(bytes[6], index + 6);
    data.set(bytes[7], index + 7);
  }
  //  void setLongAt(long value, int index) {
  //     data.set( (value >>> 56), index + 7);
  //     data.set( (value >>> 48), index + 6);
  //     data.set( (value >>> 40), index + 5);
  //     data.set( (value >>> 32), index + 4);
  //     data.set( (value >>> 24), index + 3);
  //     data.set( (value >>> 16), index + 2);
  //     data.set( (value >>> 8), index + 1);
  //     data.set( value, index);
  // }

  @override
  void setDoubleAt(double value, int index) {
    var bytes = ByteConversionUtilities.bytesFromDouble64(value,
        endian: Endian.little, doSigned: true);
    data.set(bytes[0], index);
    data.set(bytes[1], index + 1);
    data.set(bytes[2], index + 2);
    data.set(bytes[3], index + 3);
    data.set(bytes[4], index + 4);
    data.set(bytes[5], index + 5);
    data.set(bytes[6], index + 6);
    data.set(bytes[7], index + 7);
  }
}

/// Create binary representation of geometries. Currently, only text rep (hexed)
/// implementation is tested.
///
/// It should be easy to add char[] and CharSequence ByteGetter instances,
/// although the latter one is not compatible with older jdks.
///
/// I did not implement real unsigned 32-bit integers or emulate them with long,
/// as both java Arrays and Strings currently can have only 2^31-1 elements
/// (bytes), so we cannot even get or build Geometries with more than approx.
/// 2^28 coordinates (8 bytes each).
///
/// @author markus.schaber@logi-track.com
///
class BinaryWriter {
  /// Get the appropriate ValueGetter for my endianness
  ///
  /// @param bytes The ByteSetter to use
  /// @param endian the endian for the ValueSetter to use
  /// @return the ValueGetter
  static ValueSetter valueSetterForEndian(ByteSetter bytes, int endian) {
    if (endian == XDRSetter.NUMBER) {
      // XDR
      return XDRSetter(bytes);
    } else if (endian == NDRSetter.NUMBER) {
      return NDRSetter(bytes);
    } else {
      throw ArgumentError("Unknown Endian type: $endian");
    }
  }

  /// Write a hex encoded geometry
  ///
  /// Is  to protect offset counter. (Unfortunately, Java does not
  /// have neither call by reference nor multiple return values.) This is a
  /// TODO item.
  ///
  /// The geometry you put in must be consistent, geom.checkConsistency() must
  /// return true. If not, the result may be invalid WKB.
  ///
  /// @see Geometry#checkConsistency() the consistency checker
  ///
  /// @param geom the geometry to be written
  /// @param REP endianness to write the bytes with
  /// @return String containing the hex encoded geometry
  String writeHexedWithEndian(Geometry geom, int REP) {
    int length = estimateBytes(geom);
    StringByteSetter bytes = StringByteSetter(length);
    writeGeometry(geom, valueSetterForEndian(bytes, REP));
    return bytes.result();
  }

  String writeHexed(Geometry geom) {
    return writeHexedWithEndian(geom, NDRSetter.NUMBER);
  }

  /// Write a binary encoded geometry.
  ///
  /// Is  to protect offset counter. (Unfortunately, Java does not
  /// have neither call by reference nor multiple return values.) This is a
  /// TODO item.
  ///
  /// The geometry you put in must be consistent, geom.checkConsistency() must
  /// return true. If not, the result may be invalid WKB.
  ///
  /// @see Geometry#checkConsistency()
  ///
  /// @param geom the geometry to be written
  /// @param REP endianness to write the bytes with
  /// @return byte array containing the encoded geometry
  List<int> writeBinaryWithEndian(Geometry geom, int REP) {
    int length = estimateBytes(geom);
    BinaryByteSetter bytes = BinaryByteSetter(length);
    writeGeometry(geom, valueSetterForEndian(bytes, REP));
    return bytes.result();
  }

  List<int> writeBinary(Geometry geom) {
    return writeBinaryWithEndian(geom, NDRSetter.NUMBER);
  }

  /// Parse a geometry starting at offset.
  /// @param geom the geometry to write
  /// @param dest the value setting to be used for writing
  void writeGeometry(Geometry geom, ValueSetter dest) {
    // write endian flag
    dest.setByte(dest.endian);

    EGeometryType geometryType = EGeometryType.forGeometry(geom);

    // write typeword
    int typeword = geometryType.getTypeCode(geom);
    if (typeword > 7 && typeword < 3000) {
      //geom.dimension == 3) {
      typeword |= 0x80000000;
    }
    if (typeword > 1999) {
      //geom.haveMeasure) {
      typeword |= 0x40000000;
    }
    if (geom.getSRID() != BinaryParser.UNKNOWN_SRID) {
      typeword |= 0x20000000;
    }

    dest.setInt(typeword);

    if (geom.getSRID() != BinaryParser.UNKNOWN_SRID) {
      dest.setInt(geom.getSRID());
    }

    switch (geometryType) {
      case EGeometryType.POINT:
        writePoint(geom.getCoordinate(), dest);
        break;
      case EGeometryType.LINESTRING:
        writeLineString(geom, dest);
        break;
      case EGeometryType.POLYGON:
        writePolygon(geom, dest);
        break;
      case EGeometryType.MULTIPOINT:
        writeMultiPoint(geom, dest);
        break;
      case EGeometryType.MULTILINESTRING:
        writeMultiLineString(geom, dest);
        break;
      case EGeometryType.MULTIPOLYGON:
        writeMultiPolygon(geom, dest);
        break;
      case EGeometryType.GEOMETRYCOLLECTION:
        writeCollection(geom, dest);
        break;
      default:
        throw ArgumentError("Unknown Geometry Type: $geometryType");
    }
  }

  /// Writes a "slim" Point (without endiannes, srid ant type, only the
  /// ordinates and measure. Used by writeGeometry as ell as writePointArray.
  void writePoint(Coordinate geom, ValueSetter dest) {
    dest.setDouble(geom.x);
    dest.setDouble(geom.y);

    var z = geom.z;
    if (z != null && !z.isNaN) {
      //geom.dimension == 3) {
      dest.setDouble(z);
    }

    var m = geom.getM();
    if (m != null && !m.isNaN) {
      //} geom.haveMeasure) {
      dest.setDouble(m);
    }
  }

  /// Write an Array of "full" Geometries */
  void writeGeometryArray(List<Geometry> container, ValueSetter dest) {
    for (int i = 0; i < container.length; i++) {
      writeGeometry(container[i], dest);
    }
  }

  /// Write an Array of "slim" Points (without endianness, srid and type, part
  /// of LinearRing and Linestring, but not MultiPoint!
  void writePointArray(List<Coordinate> geom, ValueSetter dest) {
    // number of points
    dest.setInt(geom.length);
    for (int i = 0; i < geom.length; i++) {
      writePoint(geom[i], dest);
    }
  }

  void writeMultiPoint(MultiPoint geom, ValueSetter dest) {
    dest.setInt(geom.getNumGeometries());

    for (var i = 0; i < geom.getNumGeometries(); i++) {
      writeGeometry(geom.getGeometryN(i), dest);
    }
    // writeGeometryArray(geom.getPoints(), dest);
  }

  void writeLineString(LineString geom, ValueSetter dest) {
    writePointArray(geom.getCoordinates(), dest);
  }

  void writeLinearRing(LinearRing geom, ValueSetter dest) {
    writePointArray(geom.getCoordinates(), dest);
  }

  void writePolygon(Polygon geom, ValueSetter dest) {
    var exteriorRing = geom.getExteriorRing();
    var numInteriorRing = geom.getNumInteriorRing();
    dest.setInt(1 + numInteriorRing);
    writeLinearRing(exteriorRing, dest);
    for (int i = 0; i < numInteriorRing; i++) {
      writeLinearRing(geom.getInteriorRingN(i), dest);
    }
  }

  void writeMultiLineString(MultiLineString geom, ValueSetter dest) {
    dest.setInt(geom.getNumGeometries());
    for (var i = 0; i < geom.getNumGeometries(); i++) {
      writeGeometry(geom.getGeometryN(i), dest);
    }
    // writeGeometryArray(geom.getLines(), dest);
  }

  void writeMultiPolygon(MultiPolygon geom, ValueSetter dest) {
    dest.setInt(geom.getNumGeometries());
    for (var i = 0; i < geom.getNumGeometries(); i++) {
      writeGeometry(geom.getGeometryN(i), dest);
    }
    // writeGeometryArray(geom.getPolygons(), dest);
  }

  void writeCollection(GeometryCollection geom, ValueSetter dest) {
    dest.setInt(geom.getNumGeometries());
    for (var i = 0; i < geom.getNumGeometries(); i++) {
      writeGeometry(geom.getGeometryN(i), dest);
    }
    // writeGeometryArray(geom.getGeometries(), dest);
  }

  /// Estimate how much bytes a geometry will need in WKB.
  ///
  /// @param geom Geometry to estimate.
  /// @return estimated number of bytes
  int estimateBytes(Geometry geom) {
    int result = 0;

    // write endian flag
    result += 1;

    // write typeword
    result += 4;

    if (geom.getSRID() != BinaryParser.UNKNOWN_SRID) {
      result += 4;
    }

    EGeometryType geometryType = EGeometryType.forGeometry(geom);
    switch (geometryType) {
      case EGeometryType.POINT:
        result += estimatePoint(geom.getCoordinate());
        break;
      case EGeometryType.LINESTRING:
        result += estimateLineString(geom);
        break;
      case EGeometryType.POLYGON:
        result += estimatePolygon(geom);
        break;
      case EGeometryType.MULTIPOINT:
        result += estimateMultiPoint(geom);
        break;
      case EGeometryType.MULTILINESTRING:
        result += estimateMultiLineString(geom);
        break;
      case EGeometryType.MULTIPOLYGON:
        result += estimateMultiPolygon(geom);
        break;
      case EGeometryType.GEOMETRYCOLLECTION:
        result += estimateCollection(geom);
        break;
      default:
        throw ArgumentError("Unknown Geometry Type: $geometryType");
    }
    return result;
  }

  int estimatePoint(Coordinate c) {
    // x, y both have 8 bytes
    int result = 16;
    if (c.z != null && !c.z.isNaN) {
      //} geom.dimension == 3) {
      result += 8;
    }

    if (c.getM() != null && !c.getM().isNaN) {
      //} geom.haveMeasure) {
      result += 8;
    }
    return result;
  }

  /// Write an Array of "full" Geometries */
  int estimateGeometryArray(List<Geometry> container) {
    int result = 0;
    for (int i = 0; i < container.length; i++) {
      result += estimateBytes(container[i]);
    }
    return result;
  }

  /// Write an Array of "slim" Points (without endianness and type, part of
  /// LinearRing and Linestring, but not MultiPoint!
  int estimatePointArray(List<Coordinate> geom) {
    // number of points
    int result = 4;

    // And the amount of the points itsself, in consistent geometries
    // all points have equal size.
    if (geom.isNotEmpty) {
      result += geom.length * estimatePoint(geom[0]);
    }
    return result;
  }

  int estimateMultiPoint(MultiPoint geom) {
    // int size
    int result = 4;
    if (geom.getNumGeometries() > 0) {
      // We can shortcut here, as all subgeoms have the same fixed size
      result += geom.getNumGeometries() * estimateBytes(geom.getGeometryN(0));
    }
    return result;
  }

  int estimateLineString(LineString geom) {
    return estimatePointArray(geom.getCoordinates());
  }

  int estimateLinearRing(LinearRing geom) {
    return estimatePointArray(geom.getCoordinates());
  }

  int estimatePolygon(Polygon geom) {
    // int length
    int result = 4;
    result += estimateLinearRing(geom.getExteriorRing());
    for (int i = 0; i < geom.getNumInteriorRing(); i++) {
      result += estimateLinearRing(geom.getInteriorRingN(i));
    }
    return result;
  }

  int estimateMultiLineString(MultiLineString geom) {
    // 4-byte count + subgeometries
    int est = 4;
    for (var i = 0; i < geom.getNumGeometries(); i++) {
      est += estimateBytes(geom.getGeometryN(i));
    }
    return est;
    // return 4 + estimateGeometryArray(geom.getLines());
  }

  int estimateMultiPolygon(MultiPolygon geom) {
    // 4-byte count + subgeometries
    int est = 4;
    for (var i = 0; i < geom.getNumGeometries(); i++) {
      est += estimateBytes(geom.getGeometryN(i));
    }
    return est;
    // return 4 + estimateGeometryArray(geom.getPolygons());
  }

  int estimateCollection(GeometryCollection geom) {
    // 4-byte count + subgeometries
    int est = 4;
    for (var i = 0; i < geom.getNumGeometries(); i++) {
      est += estimateBytes(geom.getGeometryN(i));
    }
    return est;
    // return 4 + estimateGeometryArray(geom.getGeometries());
  }
}
