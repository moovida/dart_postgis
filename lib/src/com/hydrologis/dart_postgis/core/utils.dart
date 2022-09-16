part of dart_postgis;

/// Class representing a geometry_columns record.
class GeometryColumn {
  // VARIABLES
  late TableName tableName;
  late String geometryColumnName;

  /// The type, as compatible with {@link EGeometryType#fromGeometryTypeCode(int)} and {@link ESpatialiteGeometryType#forValue(int)}.
  late EGeometryType geometryType;
  late int coordinatesDimension;
  late int srid;
  late int isSpatialIndexEnabled;
}

class PostgisGeometryColumns {
  // COLUMN NAMES
  static final String TABLENAME = "geometry_columns";
  static final String F_TABLE_NAME = "f_table_name";
  static final String F_GEOMETRY_COLUMN = "f_geometry_column";
  static final String GEOMETRY_TYPE = "type";
  static final String COORD_DIMENSION = "coord_dimension";
  static final String SRID = "srid";
  static final String SPATIAL_INDEX_ENABLED = "spatial_index_enabled";

  // index
  static final String INDEX_TABLENAME = "INFORMATION_SCHEMA.INDEXES";
  static final String INDEX_TABLENAME_FIELD = "TABLE_NAME";
  static final String INDEX_TYPE_NAME = "INDEX_TYPE_NAME";
}

class PostgisUtils {
  /// Create a polygon using an envelope.
  ///
  /// @param env the envelope to use.
  /// @return the created geomerty.
  static Polygon createPolygonFromEnvelope(Envelope env) {
    double minX = env.getMinX();
    double minY = env.getMinY();
    double maxY = env.getMaxY();
    double maxX = env.getMaxX();
    return createPolygonFromBounds(minX, minY, maxX, maxY);
  }

  /// Create a polygon using boundaries.
  ///
  /// @param minX the min x.
  /// @param minY the min y.
  /// @param maxX the max x.
  /// @param maxY the max y.
  /// @return the created geomerty.
  static Polygon createPolygonFromBounds(
      double minX, double minY, double maxX, double maxY) {
    List<Coordinate> c = [
      Coordinate(minX, minY),
      Coordinate(minX, maxY),
      Coordinate(maxX, maxY),
      Coordinate(maxX, minY),
      Coordinate(minX, minY)
    ];
    return GeometryFactory.defaultPrecision().createPolygonFromCoords(c);
  }
}

/// A simple table info.
///
/// <p>If performance is needed, this should not be used.</p>
class PGQueryResult {
  String? geomName;

  /// This can optionally be used to identify record sources
  /// in case of mixed data sources (ex. merging together
  /// QueryResults from different queries.
  List<String>? ids;

  List<Geometry> geoms = [];

  List<Map<String, dynamic>> data = [];
}
