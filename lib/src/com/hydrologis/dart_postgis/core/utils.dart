part of dart_postgis;

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
