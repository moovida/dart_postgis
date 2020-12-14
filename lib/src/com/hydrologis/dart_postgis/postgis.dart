part of dart_postgis;

/// A postgis database.
///
/// @author Andrea Antonello (www.hydrologis.com)
class PostgisDb {
  static const String HM_STYLES_TABLE = "hm_styles";

  PostgresqlDb _postgresDb;

  final String _host;
  final String _dbName;
  String user;
  String pwd;
  int port;

  String jdbcUrl;

  String pgVersion;

  PostgisDb(
    this._host,
    this._dbName, {
    this.port = 5432,
    this.user,
    this.pwd,
  }) {
    _postgresDb =
        PostgresqlDb(_host, _dbName, port: port, user: user, pwd: pwd);
    jdbcUrl = 'jdbc:postgresql://$_host:$port/$_dbName';
  }

  @override
  bool operator ==(other) {
    return other is PostgisDb &&
        jdbcUrl == other.jdbcUrl &&
        user == other.user &&
        pwd == other.pwd;
  }

  @override
  int get hashCode => HashUtilities.hashObjects([jdbcUrl, user, pwd]);

  Future<bool> open({Function populateFunction}) async {
    bool opened = await _postgresDb.open(populateFunction: populateFunction);
    if (!opened) {
      return false;
    }

    var res = await _postgresDb.select("SELECT PostGIS_full_version();");
    if (res == null) {
      return false;
    }
    pgVersion = res.first.getAt(0);

    return opened;
  }

  bool isOpen() {
    return _postgresDb != null && _postgresDb.isOpen();
  }

  String get version => pgVersion;

  Future<void> close() async {
    await _postgresDb?.close();
  }

  Future<GeometryColumn> getGeometryColumnsForTable(SqlName tableName) async {
    String indexSql =
        "SELECT tablename FROM pg_indexes WHERE upper(tablename) = upper(?) and upper(indexdef) like '%USING GIST%'";
    List<String> tablesWithIndex = [];
    QueryResult queryResult =
        await _postgresDb.select(indexSql, [tableName.name]);
    if (queryResult.length == 1) {
      tablesWithIndex.add(queryResult.first.get("tablename"));
    }
    String sql = "select " +
        PostgisGeometryColumns.F_TABLE_NAME +
        ", " //
        +
        PostgisGeometryColumns.F_GEOMETRY_COLUMN +
        ", " //
        +
        PostgisGeometryColumns.GEOMETRY_TYPE +
        "," //
        +
        PostgisGeometryColumns.COORD_DIMENSION +
        ", " //
        +
        PostgisGeometryColumns.SRID +
        " from " //
        +
        PostgisGeometryColumns.TABLENAME +
        " where Lower(" +
        PostgisGeometryColumns.F_TABLE_NAME +
        ")=Lower(?)";

    queryResult = await _postgresDb.select(sql, [tableName.name]);
    GeometryColumn gc;
    if (queryResult.length == 1) {
      gc = GeometryColumn();
      var row = queryResult.first;
      String name = row.getAt(0);
      gc.tableName = SqlName(name);
      gc.geometryColumnName = row.getAt(1);
      String type = row.getAt(2);
      gc.geometryType = EGeometryType.forWktName(type);
      gc.coordinatesDimension = row.getAt(3);
      gc.srid = row.getAt(4);

      if (tablesWithIndex.contains(name)) {
        gc.isSpatialIndexEnabled = 1;
      }
    }
    return gc;
  }

  // void createSpatialTable(
  //     SqlName tableName,
  //     int tableSrid,
  //     String geometryFieldData,
  //     List<String> fieldData,
  //     List<String> foreignKeys,
  //     bool avoidIndex) {
  //   StringBuffer sb = StringBuffer();
  //   sb.write("CREATE TABLE ");
  //   sb.write(tableName.fixedName);
  //   sb.write("(");
  //   for (int i = 0; i < fieldData.length; i++) {
  //     if (i != 0) sb.write(",");
  //     sb.write(fieldData[i]);
  //   }
  //   sb.write(",");
  //   sb.write(geometryFieldData);
  //   if (foreignKeys != null) {
  //     for (int i = 0; i < foreignKeys.length; i++) {
  //       sb.write(",");
  //       sb.write(foreignKeys[i]);
  //     }
  //   }
  //   sb.write(")");

  //   _postgresDb.execute(sb.toString());

  //   List<String> g = geometryFieldData.split(RegExp(r"\s+"));
  //   addGeoPackageContentsEntry(tableName, tableSrid, null, null);
  //   addGeometryColumnsEntry(tableName, g[0], g[1], tableSrid, false, false);

  //   if (!avoidIndex) {
  //     createSpatialIndex(tableName, g[0]);
  //   }
  // }

  Envelope getTableBounds(SqlName tableName) {
// TODO
    throw RuntimeException("Not implemented yet...");
  }

  Future<String> getSpatialindexGeometryWherePiece(
      SqlName tableName, Geometry geometry) async {
    GeometryColumn gCol = await getGeometryColumnsForTable(tableName);

    int srid = geometry.getSRID();
    Envelope envelopeInternal = geometry.getEnvelopeInternal();
    Polygon bounds = PostgisUtils.createPolygonFromEnvelope(envelopeInternal);
    String sql = gCol.geometryColumnName +
        " && ST_GeomFromText('" +
        bounds.toText() +
        "',$srid) AND ST_Intersects(" +
        gCol.geometryColumnName +
        ",ST_GeomFromText('" +
        geometry.toText() +
        "',$srid))";
    return sql;
  }

  Future<String> getSpatialindexBBoxWherePiece(
      SqlName tableName, double x1, double y1, double x2, double y2) async {
    Polygon bounds = PostgisUtils.createPolygonFromBounds(x1, y1, x2, y2);
    GeometryColumn gCol = await getGeometryColumnsForTable(tableName);
    int srid = gCol.srid;

    String sql = gCol.geometryColumnName +
        " && ST_GeomFromText('" +
        bounds.toText() +
        "', $srid) AND ST_Intersects(" +
        gCol.geometryColumnName +
        ",ST_GeomFromText('" +
        bounds.toText() +
        "',$srid))";
    return sql;
  }

  /// Get the geometries of a table inside a given envelope.
  ///
  /// Note that the primary key value is put inside the geom's userdata.
  ///
  /// @param tableName
  ///            the table name.
  /// @param envelope
  ///            the envelope to check.
  /// @param prePostWhere an optional set of 3 parameters. The parameters are: a
  ///          prefix wrapper for geom, a postfix for the same and a where string
  ///          to apply. They all need to be existing if the parameter is passed.
  /// @param limit an optional limit to apply.
  /// @return The list of geometries intersecting the envelope.
  /// @throws Exception
  Future<List<Geometry>> getGeometriesIn(SqlName tableName,
      {Envelope envelope,
      Geometry intersectionGeometry,
      List<String> prePostWhere,
      int limit = -1,
      String userDataField}) async {
    List<String> wheres = [];
    String pre = "";
    String post = "";
    String where = "";
    if (prePostWhere != null && prePostWhere.length == 3) {
      if (prePostWhere[0] != null) pre = prePostWhere[0];
      if (prePostWhere[1] != null) post = prePostWhere[1];
      if (prePostWhere[2] != null) {
        where = prePostWhere[2];
        wheres.add(where);
      }
    }

    String userDataSql = userDataField != null ? ", $userDataField " : "";

    String pk = await _postgresDb.getPrimaryKey(tableName);
    GeometryColumn gCol = await getGeometryColumnsForTable(tableName);
    String sql = "SELECT " +
        pre +
        gCol.geometryColumnName +
        post +
        " as the_geom, $pk $userDataSql FROM " +
        tableName.fixedName;

    if (intersectionGeometry != null) {
      intersectionGeometry.setSRID(gCol.srid);
      String spatialindexGeometryWherePiece =
          await getSpatialindexGeometryWherePiece(
              tableName, intersectionGeometry);
      if (spatialindexGeometryWherePiece != null) {
        wheres.add(spatialindexGeometryWherePiece);
      }
    } else if (envelope != null) {
      double x1 = envelope.getMinX();
      double y1 = envelope.getMinY();
      double x2 = envelope.getMaxX();
      double y2 = envelope.getMaxY();
      String spatialindexBBoxWherePiece =
          await getSpatialindexBBoxWherePiece(tableName, x1, y1, x2, y2);
      if (spatialindexBBoxWherePiece != null) {
        wheres.add(spatialindexBBoxWherePiece);
      }
    }

    if (wheres.isNotEmpty) {
      sql += " WHERE " + wheres.join(" AND ");
    }

    if (limit > 0) {
      sql += " limit $limit";
    }

    List<Geometry> geoms = [];
    var res = await _postgresDb.select(sql);
    res.forEach((QueryResultRow map) {
      var geomBytes = map.getAt(0);
      if (geomBytes != null) {
        Geometry geom = BinaryParser().parse(geomBytes);
        var pkValue = map.getAt(1);
        if (userDataField != null) {
          geom.setUserData(map.getAt(2));
        } else {
          geom.setUserData(pkValue);
        }
        geoms.add(geom);
      }
    });
    return geoms;
  }

  Future<List<SqlName>> getTables(bool doOrder) async {
    return await _postgresDb.getTables(doOrder: doOrder);
  }

  Future<bool> hasTable(SqlName tableName) async {
    return await _postgresDb.hasTable(tableName);
  }

  /// Get the [tableName] columns as array of name, type, isPrimaryKey, notnull.
  Future<List<List>> getTableColumns(SqlName tableName) async {
    return await _postgresDb.getTableColumns(tableName);
  }

  Future<void> addGeometryXYColumnAndIndex(SqlName tableName,
      String geomColName, String geomType, String epsg) async {
    await createSpatialIndex(tableName, geomColName);
  }

  Future<String> getPrimaryKey(SqlName tableName) async {
    return await _postgresDb.getPrimaryKey(tableName);
  }

  Future<PGQueryResult> getTableData(SqlName tableName,
      {Envelope envelope, Geometry geometry, String where, int limit}) async {
    PGQueryResult queryResult = PGQueryResult();

    GeometryColumn geometryColumn = await getGeometryColumnsForTable(tableName);
    queryResult.geomName = geometryColumn.geometryColumnName;

    String sql = "select * from " + tableName.fixedName;

    if (envelope != null && geometry != null) {
      throw ArgumentError("Only one of envelope and geometry have to be set.");
    }

    List<String> wheresList = [];
    if (geometry != null) {
      String spatialindexGeometryWherePiece =
          await getSpatialindexGeometryWherePiece(tableName, geometry);
      if (spatialindexGeometryWherePiece != null) {
        wheresList.add(spatialindexGeometryWherePiece);
      }
    } else if (envelope != null) {
      double x1 = envelope.getMinX();
      double y1 = envelope.getMinY();
      double x2 = envelope.getMaxX();
      double y2 = envelope.getMaxY();
      String spatialindexBBoxWherePiece =
          await getSpatialindexBBoxWherePiece(tableName, x1, y1, x2, y2);
      if (spatialindexBBoxWherePiece != null) {
        wheresList.add(spatialindexBBoxWherePiece);
      }
    }
    if (where != null && where.isNotEmpty) {
      wheresList.add(where);
    }

    if (wheresList.isNotEmpty) {
      var wheresString = wheresList.join(" AND ");
      sql += " WHERE " + wheresString;
    }

    if (limit != null) {
      sql += " limit $limit";
    }
    var result = await _postgresDb.select(sql);
    result.forEach((QueryResultRow map) {
      Map<String, dynamic> newMap = {};
      var geomBytes = map.get(queryResult.geomName);
      if (geomBytes != null) {
        Geometry geom = BinaryParser().parse(geomBytes);
        queryResult.geoms.add(geom);
      }
      map
        ..forEach((k, v) {
          if (k != queryResult.geomName) {
            newMap[k] = v;
          }
        });
      queryResult.data.add(newMap);
    });

    return queryResult;
  }

  /// Create a spatial index
  ///
  /// @param e feature entry to create spatial index for
  Future<void> createSpatialIndex(
      SqlName tableName, String geometryName) async {
    String sql = "CREATE INDEX " +
        tableName.name +
        "__" +
        geometryName +
        "_spx ON " +
        tableName.name +
        " USING GIST (" +
        geometryName +
        ");";

    await _postgresDb.execute(sql);
  }

  /// Execute a insert, update or delete using [sql] in normal
  /// or prepared mode using [arguments].
  ///
  /// This returns the number of affected rows. Only if [getLastInsertId]
  /// is set to true, the id of the last inserted row is returned.
  Future<int> execute(String sql,
      {List<dynamic> arguments, bool getLastInsertId = false}) async {
    return await _postgresDb.execute(sql,
        arguments: arguments, getLastInsertId: getLastInsertId);
  }

  /// Update a new record using a map and a where condition.
  ///
  /// This returns the number of rows affected.
  Future<int> updateMap(
      SqlName table, Map<String, dynamic> values, String where) async {
    return await _postgresDb.updateMap(table, values, where);
  }

  Future<QueryResult> select(String sql) async {
    return await _postgresDb.select(sql);
  }

  Future<dynamic> transaction(Function transactionOperations) async {
    return await _postgresDb.transaction(transactionOperations);
  }

  /// Get the SLD xml for a given table.
  Future<String> getSld(SqlName tableName) async {
    await checkStyleTable();
    String name = tableName.name.toLowerCase();
    String sql = "select sld from " +
        HM_STYLES_TABLE +
        " where lower(tablename)='" +
        name +
        "'";
    var res = await _postgresDb.select(sql);
    if (res.length == 1) {
      var row = res.first;
      String sldString = row.get('sld');
      return sldString;
    }
    return null;
  }

  /// Update the sld string in the geopackage
  Future<void> updateSld(SqlName tableName, String sldString) async {
    await checkStyleTable();

    String name = tableName.name.toLowerCase();
    String sql = """update $HM_STYLES_TABLE 
        set sld=? where lower(tablename)='$name'
        """;
    var updated = await _postgresDb.execute(sql, arguments: [sldString]);
    if (updated == 0) {
      // need to insert
      String sql = """insert into $HM_STYLES_TABLE 
      (tablename, sld) values
        ('$name', ?);
        """;
      await _postgresDb.execute(sql, arguments: [sldString]);
    }
  }

  Future<void> checkStyleTable() async {
    if (!await _postgresDb.hasTable(SqlName(HM_STYLES_TABLE))) {
      var createTablesQuery = '''
      CREATE TABLE $HM_STYLES_TABLE (  
        tablename TEXT NOT NULL,
        sld TEXT,
        simplified TEXT
      );
      CREATE UNIQUE INDEX ${HM_STYLES_TABLE}_tablename_idx ON $HM_STYLES_TABLE (tablename);
    ''';
      var split = createTablesQuery.replaceAll("\n", "").trim().split(";");
      for (int i = 0; i < split.length; i++) {
        var sql = split[i].trim();
        if (sql.isNotEmpty) {
          await _postgresDb.execute(sql);
        }
      }
    }
  }

  dynamic geometryToSql(Geometry geom) {
    return BinaryWriter().writeHexed(geom);
  }
}
