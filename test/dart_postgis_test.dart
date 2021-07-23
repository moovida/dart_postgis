import 'package:dart_hydrologis_db/dart_hydrologis_db.dart';
import 'package:dart_jts/dart_jts.dart';
import 'package:dart_postgis/dart_postgis.dart';
import 'package:test/test.dart';

void main() {
  var sqlName = SqlName("test");
  var sqlName2 = SqlName("test2");

  group('Test connection', () {
    late PostgisDb db;
    setUpAll(() async {
      db = PostgisDb(
        "localhost",
        "test",
        port: 5432,
        user: "postgres",
        pwd: "postgres",
      );
      await db.open();

      return db.transaction((ctx) async {
        for (var sql in INIT_SQL) {
          await ctx.execute(sql);
        }
      });
    });

    test('Check utils', () async {
      bool hasTable = await db.hasTable(sqlName);
      expect(hasTable, isTrue);

      var columns = await db.getTableColumns(sqlName);
      expect(columns.length, 2);

      var geometryColumn = await db.getGeometryColumnsForTable(sqlName);
      expect(geometryColumn!.srid, 4326);
      expect(geometryColumn.coordinatesDimension, 2);
      expect(geometryColumn.geometryColumnName, "geom");
      expect(geometryColumn.geometryType.typeName, "GEOMETRY");
    });

    test('Test geometry reading', () async {
      PGQueryResult result =
          await db.getTableData(sqlName, where: "name like 'Point%'");
      expect(result.data.length, 2);
      expect(result.geomName, "geom");
      for (var i = 0; i < 2; i++) {
        var name = result.data[i]["name"];
        if (name == "Point") {
          expect(result.geoms[i].toText(), "POINT (0 0)");
        } else {
          expect(result.geoms[i].toText(), "POINT (-2 2)");
          expect(result.data[i]["name"], "Point2");
        }
      }

      result =
          await db.getTableData(sqlName, where: "name = 'PolygonWithHole'");
      expect(result.data.length, 1);
      expect(result.geomName, "geom");
      expect(result.geoms[0].toText(),
          "POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0), (1 1, 1 2, 2 2, 2 1, 1 1))");
      expect(result.data[0]["name"], "PolygonWithHole");

      result = await db.getTableData(sqlName, where: "name = 'MultiPolygon'");
      expect(result.data.length, 1);
      expect(result.geomName, "geom");
      expect(result.geoms[0].toText(),
          "MULTIPOLYGON (((1 1, 3 1, 3 3, 1 3, 1 1), (1 1, 2 1, 2 2, 1 2, 1 1)), ((-1 -1, -1 -2, -2 -2, -2 -1, -1 -1)))");
      expect(result.data[0]["name"], "MultiPolygon");

      result = await db.getTableData(sqlName, where: "name = 'Collection'");
      expect(result.data.length, 1);
      expect(result.geomName, "geom");
      expect(result.geoms[0].toText(),
          "GEOMETRYCOLLECTION (POLYGON ((1 1, 2 1, 2 2, 1 2, 1 1)), POINT (2 3), LINESTRING (2 3, 3 4))");
      expect(result.data[0]["name"], "Collection");
    });

    test('Spatial query test', () async {
      List<Geometry> result = await db.getGeometriesIn(sqlName,
          envelope: Envelope(9, 11, 9, 11), userDataField: "name");
      expect(result.length, 1);
      expect(result[0].toText(),
          "POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0), (1 1, 1 2, 2 2, 2 1, 1 1))");
    });
    test('Test geometry writing', () async {
      await db.transaction((ctx) async {
        await ctx.execute("drop table if exists ${sqlName2.name} cascade;");
        await ctx.execute(
            "CREATE TABLE ${sqlName2.name} (name varchar, geom geometry(geometry, 4326));");
      });

      var wktReader = WKTReader();
      var geomTxt = "POINT (-2 2)";
      var name = 'Point2';
      await checkInsertSelect(wktReader, geomTxt, sqlName2, db, name);
      geomTxt = "MULTIPOINT ((2 1), (1 2))";
      name = 'MultiPoint';
      await checkInsertSelect(wktReader, geomTxt, sqlName2, db, name);
      geomTxt = "LINESTRING (0 0, 1 1, 2 1, 2 2)";
      name = 'LineString';
      await checkInsertSelect(wktReader, geomTxt, sqlName2, db, name);
      geomTxt = "MULTILINESTRING ((1 0, 0 1, 3 2), (3 2, 5 4))";
      name = 'MultiLineString';
      await checkInsertSelect(wktReader, geomTxt, sqlName2, db, name);
      geomTxt =
          "POLYGON ((0 0, 4 0, 4 4, 0 4, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))";
      name = 'Polygon';
      await checkInsertSelect(wktReader, geomTxt, sqlName2, db, name);
      geomTxt =
          "MULTIPOLYGON (((1 1, 3 1, 3 3, 1 3, 1 1), (1 1, 2 1, 2 2, 1 2, 1 1)), ((-1 -1, -1 -2, -2 -2, -2 -1, -1 -1)))";
      name = 'MultiPolygon';
      await checkInsertSelect(wktReader, geomTxt, sqlName2, db, name);
      geomTxt =
          "POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0), (1 1, 1 2, 2 2, 2 1, 1 1))";
      name = 'PolygonWithHole';
      await checkInsertSelect(wktReader, geomTxt, sqlName2, db, name);
      geomTxt =
          "GEOMETRYCOLLECTION (POLYGON ((1 1, 2 1, 2 2, 1 2, 1 1)), POINT (2 3), LINESTRING (2 3, 3 4))";
      name = 'geometryCollection';
      await checkInsertSelect(wktReader, geomTxt, sqlName2, db, name);
    });
  });
}

Future checkInsertSelect(WKTReader wktReader, String geomTxt, SqlName sqlName2,
    PostgisDb db, String name) async {
  var geom = wktReader.read(geomTxt)!;
  geom.setSRID(4326);
  var geomBytes = BinaryWriter().writeHexed(geom);
  // print(geomBytes);
  var sql = "insert into ${sqlName2.name} values (?, ?)";
  await db.execute(sql, arguments: [name, geomBytes]);
  PGQueryResult result =
      await db.getTableData(sqlName2, where: "name = '$name'");
  expect(result.data.length, 1);
  expect(result.geoms[0].toText(), geomTxt);
}

const INIT_SQL = [
  """drop table if exists test cascade;""",
  """CREATE TABLE test (name varchar, geom geometry(geometry, 4326));""",
  """CREATE INDEX test__geom_spx ON test USING GIST (geom);"""
      """
    INSERT INTO test VALUES
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
