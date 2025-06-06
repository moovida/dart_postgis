part of dart_postgis;

/// A postgis database.
///
/// @author Andrea Antonello (www.hydrologis.com)
class PostgisDb {
  static const String HM_STYLES_TABLE = "hm_styles";

  late PostgresqlDb _postgresDb;

  final String _host;
  final String _dbName;
  String? user;
  String? pwd;
  int port;
  bool? _canHanldeStyle;
  bool _canCreateTable = true;

  late String jdbcUrl;

  String pgVersion = "";

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

  Future<bool> open({
    Function? populateFunction,
    int timeoutInSeconds = 30,
    int queryTimeoutInSeconds = 30,
    String timeZone = 'UTC',
    bool useSSL = false,
    bool isUnixSocket = false,
    bool allowClearTextPassword = false,
  }) async {
    bool opened = await _postgresDb.open(
      populateFunction: populateFunction,
      timeoutInSeconds: timeoutInSeconds,
      queryTimeoutInSeconds: queryTimeoutInSeconds,
      timeZone: timeZone,
      useSSL: useSSL,
      isUnixSocket: isUnixSocket,
      allowClearTextPassword: allowClearTextPassword,
    );
    if (!opened) {
      return false;
    }

    // check if the user can create tables
    var res = await _postgresDb
        .select("SELECT has_database_privilege('$user','$_dbName','CREATE')");
    if (res != null && res.length == 1) {
      _canCreateTable = res.first.getAt(0);
    }

    res = await _postgresDb.select("SELECT PostGIS_full_version();");
    if (res == null) {
      return false;
    }
    pgVersion = res.first.getAt(0);

    return opened;
  }

  bool isOpen() {
    return _postgresDb.isOpen();
  }

  String get version => pgVersion;

  bool canCreateTable() {
    return _canCreateTable;
  }

  Future<void> close() async {
    await _postgresDb.close();
  }

  /// Get the names of the geometry tables.
  ///
  /// This is the fast was, as [getGeometryColumnsForTable] also checks
  /// for the spatial index availability and might be slow for many tables.
  Future<List<String>> getGeometryTables() async {
    List<String> geomTables = [];
    QueryResult? queryResult = await _postgresDb
        .select("select f_table_schema,f_table_name from geometry_columns");
    queryResult!.forEach((QueryResultRow row) {
      var tableName = row.getAt(1);
      var schemaName = row.getAt(0);
      geomTables.add(schemaName + "." + tableName);
    });
    geomTables.sort();
    return geomTables;
  }

  Future<GeometryColumn?> getGeometryColumnsForTable(
      TableName tableName) async {
    String indexSql =
        "SELECT tablename FROM pg_indexes WHERE upper(tablename) = upper(?) and upper(indexdef) like '%USING GIST%'";
    List<String> tablesWithIndex = [];
    QueryResult? queryResult =
        await _postgresDb.select(indexSql, [tableName.name]);
    if (queryResult != null && queryResult.length > 0) {
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
    GeometryColumn? gc;
    if (queryResult != null && queryResult.length > 0) {
      gc = GeometryColumn();
      var row = queryResult.first;
      String name = row.getAt(0);
      gc.tableName = name;
      gc.geometryColumnName = row.getAt(1);
      String type = row.getAt(2);
      gc.geometryType = EGeometryType.forWktName(type);
      gc.coordinatesDimension = row.getAt(3);
      gc.srid = row.getAt(4);

      if (gc.geometryType == EGeometryType.GEOMETRY) {
        List<Geometry> list = await getGeometriesIn(tableName, limit: 1);
        if (list.isNotEmpty) {
          Geometry g = list[0];
          gc.geometryType = EGeometryType.forGeometry(g);
        }
      }

      if (tablesWithIndex.contains(name)) {
        gc.isSpatialIndexEnabled = 1;
      }
    }
    return gc;
  }

  Future<List<dynamic>?> getGeometryColumnNameAndSridForTable(
      TableName tableName) async {
    String sql = "select " +
        PostgisGeometryColumns.F_GEOMETRY_COLUMN +
        ", " //
        +
        PostgisGeometryColumns.SRID +
        " from " //
        +
        PostgisGeometryColumns.TABLENAME +
        " where Lower(" +
        PostgisGeometryColumns.F_TABLE_NAME +
        ")=Lower(?)";

    var queryResult = await _postgresDb.select(sql, [tableName.name]);
    if (queryResult != null && queryResult.length == 1) {
      var row = queryResult.first;
      return [row.getAt(0), row.getAt(1)];
    }
    return null;
  }

  // void createSpatialTable(
  //     TableName tableName,
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

  Envelope getTableBounds(TableName tableName) {
// TODO
    throw RuntimeException("Not implemented yet...");
  }

  Future<String?> getSpatialindexGeometryWherePiece(
      TableName tableName, Geometry geometry) async {
    GeometryColumn? gCol = await getGeometryColumnsForTable(tableName);
    if (gCol == null) {
      return null;
    }

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

  Future<String?> getSpatialindexBBoxWherePiece(
      TableName tableName, double x1, double y1, double x2, double y2) async {
    Polygon bounds = PostgisUtils.createPolygonFromBounds(x1, y1, x2, y2);
    GeometryColumn? gCol = await getGeometryColumnsForTable(tableName);
    if (gCol == null) {
      return null;
    }
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
  Future<List<Geometry>> getGeometriesIn(TableName tableName,
      {Envelope? envelope,
      Geometry? intersectionGeometry,
      List<String?>? prePostWhere,
      int limit = -1,
      String? userDataField}) async {
    List<String> wheres = [];
    String pre = "";
    String post = "";
    String where = "";
    if (prePostWhere != null && prePostWhere.length == 3) {
      if (prePostWhere[0] != null) pre = prePostWhere[0]!;
      if (prePostWhere[1] != null) post = prePostWhere[1]!;
      if (prePostWhere[2] != null) {
        where = prePostWhere[2]!;
        wheres.add(where);
      }
    }

    String userDataSql = userDataField != null ? ", $userDataField " : "";

    String? pk = await _postgresDb.getPrimaryKey(tableName);
    var gcAndSrid = await getGeometryColumnNameAndSridForTable(tableName);
    if (gcAndSrid == null) {
      return [];
    }
    String sql = "SELECT " +
        pre +
        gcAndSrid[0] +
        post +
        " as the_geom, $pk $userDataSql FROM " +
        tableName.fixedDoubleName;

    if (intersectionGeometry != null) {
      intersectionGeometry.setSRID(gcAndSrid[1]);
      String? spatialindexGeometryWherePiece =
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
      String? spatialindexBBoxWherePiece =
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
    if (res != null) {
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
    }
    return geoms;
  }

  Future<List<TableName>> getTables(bool doOrder) async {
    return await _postgresDb.getTables(doOrder: doOrder);
  }

  Future<bool> hasTable(TableName tableName) async {
    return await _postgresDb.hasTable(tableName);
  }

  /// Get the [tableName] columns as array of name, type, isPrimaryKey, notnull.
  Future<List<List>> getTableColumns(TableName tableName) async {
    return await _postgresDb.getTableColumns(tableName);
  }

  Future<void> addGeometryXYColumnAndIndex(TableName tableName,
      String geomColName, String geomType, String epsg) async {
    await createSpatialIndex(tableName, geomColName);
  }

  Future<String?> getPrimaryKey(TableName tableName) async {
    return await _postgresDb.getPrimaryKey(tableName);
  }

  Future<FeatureCollection> getTableData(TableName tableName,
      {Envelope? envelope,
      Geometry? geometry,
      String? where,
      int? limit}) async {
    FeatureCollection queryResult = FeatureCollection();

    GeometryColumn? geometryColumn =
        await getGeometryColumnsForTable(tableName);
    if (geometryColumn != null) {
      queryResult.geomName = geometryColumn.geometryColumnName;
    }

    String sql = "select * from " + tableName.fixedDoubleName;

    if (envelope != null && geometry != null) {
      throw ArgumentError("Only one of envelope and geometry have to be set.");
    }

    List<String> wheresList = [];
    if (geometry != null) {
      String? spatialindexGeometryWherePiece =
          await getSpatialindexGeometryWherePiece(tableName, geometry);
      if (spatialindexGeometryWherePiece != null) {
        wheresList.add(spatialindexGeometryWherePiece);
      }
    } else if (envelope != null) {
      double x1 = envelope.getMinX();
      double y1 = envelope.getMinY();
      double x2 = envelope.getMaxX();
      double y2 = envelope.getMaxY();
      String? spatialindexBBoxWherePiece =
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
    if (result != null && queryResult.geomName != null) {
      result.forEach((QueryResultRow map) {
        Feature feature = Feature();

        var geomBytes = map.get(queryResult.geomName!);
        if (geomBytes != null) {
          Geometry geom = BinaryParser().parse(geomBytes);
          feature.geometry = geom;
        }
        map.forEach((k, v) {
          if (k != queryResult.geomName) {
            feature.attributes[k] = v;
          }
        });

        queryResult.features.add(feature);
      });
    }

    return queryResult;
  }

  /// Create a spatial index
  ///
  /// @param e feature entry to create spatial index for
  Future<void> createSpatialIndex(
      TableName tableName, String geometryName) async {
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
  Future<int?> execute(String sql,
      {List<dynamic>? arguments, bool getLastInsertId = false}) async {
    return await _postgresDb.execute(sql,
        arguments: arguments, getLastInsertId: getLastInsertId);
  }

  /// Update a new record using a map and a where condition.
  ///
  /// This returns the number of rows affected.
  Future<int?> updateMap(
      TableName table, Map<String, dynamic> values, String where) async {
    return await _postgresDb.updateMap(table, values, where);
  }

  Future<QueryResult?> select(String sql) async {
    return await _postgresDb.select(sql);
  }

  Future<dynamic> transaction(Function transactionOperations) async {
    return await _postgresDb.transaction(transactionOperations);
  }

  /// Get the SLD xml for a given table.
  Future<String?> getSld(TableName tableName) async {
    if (_canHanldeStyle != null && _canHanldeStyle == false) {
      return Future.value(null);
    }
    if (await checkStyleTable()) {
      String name = tableName.name.toLowerCase();
      String sql = "select sld from " +
          HM_STYLES_TABLE +
          " where lower(tablename)='" +
          name +
          "'";
      var res = await _postgresDb.select(sql);
      if (res != null && res.length == 1) {
        var row = res.first;
        String sldString = row.get('sld');
        return sldString;
      }
    }
    return null;
  }

  /// Update the sld string in the geopackage
  Future<void> updateSld(TableName tableName, String sldString) async {
    if (_canHanldeStyle != null && _canHanldeStyle == false) {
      return;
    }
    if (await checkStyleTable()) {
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
  }

  Future<bool> canHandleStyle() async {
    if (_canHanldeStyle == null) {
      try {
        await checkStyleTable();
      } catch (e) {
        // ignore, needed only to get bool
      }
    }
    return _canHanldeStyle!;
  }

  Future<bool> checkStyleTable() async {
    if (!await _postgresDb.hasTable(TableName(HM_STYLES_TABLE))) {
      if (_canCreateTable) {
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
            try {
              await _postgresDb.execute(sql);
              _canHanldeStyle = true;
            } catch (e) {
              _canHanldeStyle = false;
              return false;
            }
          }
        }
        _canHanldeStyle = true;
      } else {
        _canHanldeStyle = false;
      }
    } else {
      _canHanldeStyle = true;
    }
    return true;
  }

  dynamic geometryToSql(Geometry geom) {
    return BinaryWriter().writeHexed(geom);
  }
}
