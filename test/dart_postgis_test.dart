import 'package:dart_hydrologis_db/dart_hydrologis_db.dart';
import 'package:dart_hydrologis_utils/dart_hydrologis_utils.dart';
import 'package:dart_jts/dart_jts.dart';
import 'package:dart_postgis/dart_postgis.dart';
import 'package:test/test.dart';

void main() {
  var tableName = TableName("myschema.01-test");
  var tableName2 = TableName("test2");

  var INIT_SQL = [
    """drop table if exists ${tableName.fixedDoubleName} cascade;""",
    """CREATE SCHEMA IF NOT EXISTS ${tableName.getSchema()};""",
    """CREATE TABLE ${tableName.fixedDoubleName} (name varchar, geom geometry(geometry, 4326));""",
    """CREATE INDEX _${tableName.name.replaceAll("-", "_")}__geom_spx ON ${tableName.fixedDoubleName} USING GIST (geom);""",
    """
      INSERT INTO ${tableName.fixedDoubleName} VALUES
          ('Point', ST_GeomFromText('POINT(0 0)', 4326)),
          ('Point2', ST_GeomFromText('POINT(-2 2)', 4326)),
          ('MultiPoint', ST_GeomFromText('MULTIPOINT(2 1,1 2)', 4326)),
          ('Linestring', ST_GeomFromText('LINESTRING(0 0, 1 1, 2 1, 2 2)', 4326)),
          ('MultiLinestring', ST_GeomFromText('MULTILINESTRING((1 0,0 1,3 2),(3 2,5 4))', 4326)),
          ('Polygon', ST_GeomFromText('POLYGON((0 0,4 0,4 4,0 4,0 0),(1 1, 2 1, 2 2, 1 2,1 1))', 4326)),
          ('PolygonWithHole', ST_GeomFromText('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(1 1, 1 2, 2 2, 2 1, 1 1))', 4326)),
          ('MultiPolygon', ST_GeomFromText('MULTIPOLYGON(((1 1,3 1,3 3,1 3,1 1),(1 1,2 1,2 2,1 2,1 1)), ((-1 -1,-1 -2,-2 -2,-2 -1,-1 -1)))', 4326)),
          ('Collection', ST_GeomFromText('GEOMETRYCOLLECTION(POLYGON((1 1, 2 1, 2 2, 1 2,1 1)),POINT(2 3),LINESTRING(2 3,3 4))', 4326));
    """
  ];

  group('Test connection', () {
    late PostgisDb db;
    setUpAll(() async {
      db = PostgisDb(
        "localhost",
        "test",
        port: 5432,
        user: "test",
        pwd: "test",
      );
      await db.open();

      return db.transaction((ctx) async {
        for (var sql in INIT_SQL) {
          print(sql);
          await ctx.execute(sql);
        }
      });
    });

    test('Check utils', () async {
      var canCreateTable = db.canCreateTable();
      expect(canCreateTable, isTrue);

      bool hasTable = await db.hasTable(tableName);
      expect(hasTable, isTrue);

      var columns = await db.getTableColumns(tableName);
      expect(columns.length, 2);

      var geometryColumn = await db.getGeometryColumnsForTable(tableName);
      expect(geometryColumn!.srid, 4326);
      expect(geometryColumn.coordinatesDimension, 2);
      expect(geometryColumn.geometryColumnName, "geom");
      expect(geometryColumn.geometryType.typeName, "Point");

      List<String> tableNames = await db.getGeometryTables();
      tableNames = tableNames
          .where((element) => element.startsWith("myschema"))
          .toList();
      expect(tableNames.length, 1);
    });

    test('Test geometry reading', () async {
      FeatureCollection result =
          await db.getTableData(tableName, where: "name like 'Point%'");
      expect(result.features.length, 2);
      expect(result.geomName, "geom");
      for (var i = 0; i < 2; i++) {
        var name = result.features[i].attributes["name"];
        if (name == "Point") {
          expect(result.features[i].geometry!.toText(), "POINT (0 0)");
        } else {
          expect(result.features[i].geometry!.toText(), "POINT (-2 2)");
          expect(result.features[i].attributes["name"], "Point2");
        }
      }

      result =
          await db.getTableData(tableName, where: "name = 'PolygonWithHole'");
      expect(result.features.length, 1);
      expect(result.geomName, "geom");
      expect(result.features[0].geometry!.toText(),
          "POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0), (1 1, 1 2, 2 2, 2 1, 1 1))");
      expect(result.features[0].attributes["name"], "PolygonWithHole");

      result = await db.getTableData(tableName, where: "name = 'MultiPolygon'");
      expect(result.features.length, 1);
      expect(result.geomName, "geom");
      expect(result.features[0].geometry!.toText(),
          "MULTIPOLYGON (((1 1, 3 1, 3 3, 1 3, 1 1), (1 1, 2 1, 2 2, 1 2, 1 1)), ((-1 -1, -1 -2, -2 -2, -2 -1, -1 -1)))");
      expect(result.features[0].attributes["name"], "MultiPolygon");

      result = await db.getTableData(tableName, where: "name = 'Collection'");
      expect(result.features.length, 1);
      expect(result.geomName, "geom");
      expect(result.features[0].geometry!.toText(),
          "GEOMETRYCOLLECTION (POLYGON ((1 1, 2 1, 2 2, 1 2, 1 1)), POINT (2 3), LINESTRING (2 3, 3 4))");
      expect(result.features[0].attributes["name"], "Collection");
    });

    test('Spatial query test', () async {
      List<Geometry> result = await db.getGeometriesIn(tableName,
          envelope: Envelope(9, 11, 9, 11), userDataField: "name");
      expect(result.length, 1);
      expect(result[0].toText(),
          "POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0), (1 1, 1 2, 2 2, 2 1, 1 1))");
    });
    test('Test geometry writing', () async {
      await db.transaction((ctx) async {
        await ctx.execute(
            "drop table if exists ${tableName2.fixedDoubleName} cascade;");
        await ctx.execute(
            "CREATE TABLE ${tableName2.fixedDoubleName} (name varchar, geom geometry(geometry, 4326));");
      });

      var wktReader = WKTReader();
      var geomTxt = "POINT (-2 2)";
      var name = 'Point2';
      await checkInsertSelect(wktReader, geomTxt, tableName2, db, name);
      geomTxt = "MULTIPOINT ((2 1), (1 2))";
      name = 'MultiPoint';
      await checkInsertSelect(wktReader, geomTxt, tableName2, db, name);
      geomTxt = "LINESTRING (0 0, 1 1, 2 1, 2 2)";
      name = 'LineString';
      await checkInsertSelect(wktReader, geomTxt, tableName2, db, name);
      geomTxt = "MULTILINESTRING ((1 0, 0 1, 3 2), (3 2, 5 4))";
      name = 'MultiLineString';
      await checkInsertSelect(wktReader, geomTxt, tableName2, db, name);
      geomTxt =
          "POLYGON ((0 0, 4 0, 4 4, 0 4, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))";
      name = 'Polygon';
      await checkInsertSelect(wktReader, geomTxt, tableName2, db, name);
      geomTxt =
          "MULTIPOLYGON (((1 1, 3 1, 3 3, 1 3, 1 1), (1 1, 2 1, 2 2, 1 2, 1 1)), ((-1 -1, -1 -2, -2 -2, -2 -1, -1 -1)))";
      name = 'MultiPolygon';
      await checkInsertSelect(wktReader, geomTxt, tableName2, db, name);
      geomTxt =
          "POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0), (1 1, 1 2, 2 2, 2 1, 1 1))";
      name = 'PolygonWithHole';
      await checkInsertSelect(wktReader, geomTxt, tableName2, db, name);
      geomTxt =
          "GEOMETRYCOLLECTION (POLYGON ((1 1, 2 1, 2 2, 1 2, 1 1)), POINT (2 3), LINESTRING (2 3, 3 4))";
      name = 'geometryCollection';
      await checkInsertSelect(wktReader, geomTxt, tableName2, db, name);
    });
  });
}

Future checkInsertSelect(WKTReader wktReader, String geomTxt,
    TableName tableName2, PostgisDb db, String name) async {
  var geom = wktReader.read(geomTxt)!;
  geom.setSRID(4326);
  var geomBytes = BinaryWriter().writeHexed(geom);
  // print(geomBytes);
  var sql = "insert into ${tableName2.fixedDoubleName} values (?, ?)";
  await db.execute(sql, arguments: [name, geomBytes]);
  var result = await db.getTableData(tableName2, where: "name = '$name'");
  expect(result.features.length, 1);
  expect(result.features[0].geometry!.toText(), geomTxt);
}
