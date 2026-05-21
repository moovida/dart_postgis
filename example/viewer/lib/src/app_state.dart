import 'package:dart_hydrologis_db/dart_hydrologis_db.dart' as hdb;
import 'package:dart_postgis/dart_postgis.dart' as pg;
import 'package:flutter/material.dart';

class ColumnItem {
  final String name;
  final String type;
  final bool isPrimaryKey;
  final bool isGeometry;
  final String? geometryType; // e.g. "MULTILINESTRING", "POINT"

  const ColumnItem({
    required this.name,
    required this.type,
    required this.isPrimaryKey,
    this.isGeometry = false,
    this.geometryType,
  });
}

class TableItem {
  final String name;
  final String schema;
  bool isGeometry;
  List<ColumnItem>? columns;

  TableItem({required this.name, required this.schema, this.isGeometry = false});

  String get fullName => '$schema.$name';
  hdb.TableName get tableName => hdb.TableName('$schema.$name');
}

class SchemaItem {
  final String name;
  final List<TableItem> tables;
  SchemaItem({required this.name, required this.tables});
}

class ViewerResult {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final int elapsedMs;
  final bool isError;

  const ViewerResult({
    required this.columns,
    required this.rows,
    required this.elapsedMs,
    this.isError = false,
  });
}

class AppState extends ChangeNotifier {
  pg.PostgisDb? _db;

  bool _isConnected = false;
  bool _isLoading = false;
  String _status = 'Not connected.';
  String _connectionLabel = '';

  List<SchemaItem> schemas = [];
  ViewerResult? queryResult;
  bool isExecuting = false;

  final List<TextEditingController> editors =
      List.generate(5, (_) => TextEditingController());
  int activeEditorIndex = 0;

  int queryLimit = 1000;
  bool applyLimit = true;

  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String get status => _status;
  String get connectionLabel => _connectionLabel;

  Future<void> connect({
    required String host,
    required int port,
    required String dbName,
    required String user,
    required String pwd,
    bool useSSL = true,
    bool allowClearTextPassword = false,
  }) async {
    _isLoading = true;
    _status = 'Connecting…';
    notifyListeners();

    try {
      final db = pg.PostgisDb(host, dbName, port: port, user: user, pwd: pwd);
      await db.open(
        useSSL: useSSL,
        allowClearTextPassword: allowClearTextPassword,
      );
      _db = db;
      _isConnected = true;
      _connectionLabel = '$host:$port/$dbName';
      await _loadTree();
      _status =
          'Connected to $_connectionLabel · PostGIS ${db.version.split(" ").first}';
    } catch (e) {
      _db = null;
      _isConnected = false;
      _status = 'Connection failed: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _db?.close();
    _db = null;
    _isConnected = false;
    _connectionLabel = '';
    schemas = [];
    queryResult = null;
    _status = 'Disconnected.';
    notifyListeners();
  }

  Future<void> refreshTree() async {
    if (_db == null) return;
    _status = 'Refreshing tree…';
    notifyListeners();
    await _loadTree();
    _status = 'Connected to $_connectionLabel';
    notifyListeners();
  }

  Future<void> _loadTree() async {
    final schemaList = await _db!.getSchemas(doOrder: true);
    final tableList = await _db!.getTables(true);

    // geometry tables returned as "schema.tablename" strings
    final geomTables = (await _db!.getGeometryTables()).toSet();

    final Map<String, List<TableItem>> bySchema = {};
    for (final t in tableList) {
      final schema = t.getSchema();
      bySchema.putIfAbsent(schema, () => []);
      bySchema[schema]!.add(TableItem(
        name: t.name,
        schema: schema,
        isGeometry: geomTables.contains('$schema.${t.name}'),
      ));
    }

    schemas = [];
    for (final s in schemaList) {
      if (bySchema.containsKey(s.name)) {
        schemas.add(SchemaItem(name: s.name, tables: bySchema[s.name]!));
      }
    }
    for (final entry in bySchema.entries) {
      if (!schemas.any((s) => s.name == entry.key)) {
        schemas.add(SchemaItem(name: entry.key, tables: entry.value));
      }
    }
  }

  Future<void> loadTableColumns(TableItem table) async {
    if (_db == null || table.columns != null) return;

    final cols = await _db!.getTableColumns(table.tableName);
    final pk = await _db!.getPrimaryKey(table.tableName);

    String? geomColName;
    String? geomTypeName;
    if (table.isGeometry) {
      final gc = await _db!.getGeometryColumnsForTable(table.tableName);
      if (gc != null) {
        geomColName = gc.geometryColumnName;
        geomTypeName = gc.geometryType.typeName;
      }
    }

    table.columns = cols.map((c) {
      final colName = c[0] as String;
      final isGeomCol = colName == geomColName;
      return ColumnItem(
        name: colName,
        type: isGeomCol ? (geomTypeName ?? c[1] as String) : c[1] as String,
        isPrimaryKey: colName == pk,
        isGeometry: isGeomCol,
        geometryType: isGeomCol ? geomTypeName : null,
      );
    }).toList();

    notifyListeners();
  }

  void setActiveEditor(int index) {
    activeEditorIndex = index;
    notifyListeners();
  }

  void insertInActiveEditor(String text) {
    final ctrl = editors[activeEditorIndex];
    final sel = ctrl.selection;
    final current = ctrl.text;
    final pos =
        (sel.isValid && sel.baseOffset >= 0) ? sel.baseOffset : current.length;
    ctrl.text = current.substring(0, pos) + text + current.substring(pos);
    ctrl.selection = TextSelection.collapsed(offset: pos + text.length);
  }

  Future<void> runTableSelectQuery(TableItem table) async {
    if (_db == null || isExecuting) return;
    await loadTableColumns(table);

    String sql;
    if (table.isGeometry && table.columns != null && table.columns!.isNotEmpty) {
      final exprs = table.columns!.map((c) {
        if (c.isGeometry) return 'ST_AsText(${c.name}) AS ${c.name}';
        return c.name;
      }).join(',\n  ');
      sql = 'SELECT\n  $exprs\nFROM ${table.fullName}';
    } else {
      sql = 'SELECT *\nFROM ${table.fullName}';
    }

    if (applyLimit) sql = '$sql\nLIMIT $queryLimit';
    await _runSql(sql);
  }

  Future<void> _runSql(String sql) async {
    isExecuting = true;
    queryResult = null;
    _status = 'Executing…';
    notifyListeners();

    final sw = Stopwatch()..start();
    try {
      final res = await _db!.select(sql);
      sw.stop();
      final cols = <String>[];
      final rows = <List<dynamic>>[];
      if (res != null && res.length > 0) {
        res.first.forEach((dynamic k, dynamic v) => cols.add(k as String));
        res.forEach((dynamic row) {
          final r = <dynamic>[];
          row.forEach((dynamic k, dynamic v) => r.add(v));
          rows.add(r);
        });
      }
      queryResult = ViewerResult(
        columns: cols,
        rows: rows,
        elapsedMs: sw.elapsedMilliseconds,
      );
      _status = '${rows.length} rows in ${sw.elapsedMilliseconds} ms';
    } catch (e) {
      sw.stop();
      queryResult = ViewerResult(
        columns: ['Error'],
        rows: [[e.toString()]],
        elapsedMs: sw.elapsedMilliseconds,
        isError: true,
      );
      _status = 'Error: $e';
    } finally {
      isExecuting = false;
      notifyListeners();
    }
  }

  Future<void> executeQuery() async {
    if (_db == null) return;
    var sql = editors[activeEditorIndex].text.trim();
    if (sql.isEmpty) return;

    final lsql = sql.toLowerCase();
    final isSelect = lsql.startsWith('select') ||
        lsql.startsWith('with') ||
        lsql.startsWith('explain');

    if (isSelect && applyLimit && !RegExp(r'\blimit\b').hasMatch(lsql)) {
      sql = sql.trimRight();
      if (sql.endsWith(';')) sql = sql.substring(0, sql.length - 1);
      sql = '$sql\nLIMIT $queryLimit';
    }

    isExecuting = true;
    queryResult = null;
    _status = 'Executing…';
    notifyListeners();

    final sw = Stopwatch()..start();
    try {
      if (isSelect) {
        final res = await _db!.select(sql);
        sw.stop();
        final cols = <String>[];
        final rows = <List<dynamic>>[];
        if (res != null && res.length > 0) {
          res.first.forEach((dynamic k, dynamic v) => cols.add(k as String));
          res.forEach((dynamic row) {
            final r = <dynamic>[];
            row.forEach((dynamic k, dynamic v) => r.add(v));
            rows.add(r);
          });
        }
        queryResult = ViewerResult(
          columns: cols,
          rows: rows,
          elapsedMs: sw.elapsedMilliseconds,
        );
        _status = '${rows.length} rows in ${sw.elapsedMilliseconds} ms';
      } else {
        final affected = await _db!.execute(sql);
        sw.stop();
        queryResult = ViewerResult(
          columns: ['Result'],
          rows: [['${affected ?? 0} rows affected']],
          elapsedMs: sw.elapsedMilliseconds,
        );
        _status =
            '${affected ?? 0} rows affected in ${sw.elapsedMilliseconds} ms';
      }
    } catch (e) {
      sw.stop();
      queryResult = ViewerResult(
        columns: ['Error'],
        rows: [[e.toString()]],
        elapsedMs: sw.elapsedMilliseconds,
        isError: true,
      );
      _status = 'Error: $e';
    } finally {
      isExecuting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final c in editors) {
      c.dispose();
    }
    _db?.close();
    super.dispose();
  }
}
