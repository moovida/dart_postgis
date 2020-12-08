import 'package:dart_hydrologis_db/dart_hydrologis_db.dart';
import 'package:dart_postgis/dart_postgis.dart';
import 'package:test/test.dart';

void main() {
  group('Test connection', () {
    PostgisDb db;
    setUpAll(() {
      db = PostgisDb("localhost", "database_2020",
          port: 5432, user: "god", pwd: "god");
      return db.open();
    });

    test('Check utils', () async {
      bool hasTable = await db.hasTable(SqlName("pipes"));
      expect(hasTable, isTrue);
    });

    test('Table data test', () async {
      PGQueryResult result =
          await db.getTableData(SqlName("clusters"), where: "id=2301");
      // expect(hasTable, isTrue);
      print(result.geoms[0]);
    });
  });
}
