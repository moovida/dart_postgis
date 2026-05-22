import 'package:dart_hydrologis_db/dart_hydrologis_db.dart' as hdb;
import 'package:dart_postgis/dart_postgis.dart' as pg;
import 'package:flutter/material.dart';

class ColumnItem {
  final String name;
  final String type;
  final bool isPrimaryKey;
  final bool isGeometry;
  final String? geometryType;
  final int? srid;
  final bool hasSpatialIndex;

  const ColumnItem({
    required this.name,
    required this.type,
    required this.isPrimaryKey,
    this.isGeometry = false,
    this.geometryType,
    this.srid,
    this.hasSpatialIndex = false,
  });
}

class IndexInfo {
  final String name;
  final String type; // btree, gist, gin, hash, …
  final String columns;
  final bool isUnique;

  const IndexInfo({
    required this.name,
    required this.type,
    required this.columns,
    this.isUnique = false,
  });
}

class ForeignKeyInfo {
  final String column;
  final String refSchema;
  final String refTable;
  final String refColumn;

  const ForeignKeyInfo({
    required this.column,
    required this.refSchema,
    required this.refTable,
    required this.refColumn,
  });
}

class TableItem {
  final String name;
  final String schema;
  bool isGeometry;
  List<ColumnItem>? columns;
  List<IndexInfo>? indexes;
  List<ForeignKeyInfo>? foreignKeys;

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

  // Stored for database switching
  String? _host;
  int? _port;
  String? _dbName;
  String? _user;
  String? _pwd;
  bool _useSSL = true;
  bool _allowClearTextPassword = false;

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
  String get currentDbName => _dbName ?? '';

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
      // Store params for database switching
      _host = host; _port = port; _dbName = dbName;
      _user = user; _pwd = pwd;
      _useSSL = useSSL; _allowClearTextPassword = allowClearTextPassword;
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

  Future<List<String>> listDatabases() async {
    if (_db == null) return [];
    final res = await _db!.select(
      "SELECT datname FROM pg_database "
      "WHERE datistemplate = false AND datallowconn = true "
      "ORDER BY datname",
    );
    final dbs = <String>[];
    res?.forEach((dynamic row) {
      final name = row.get('datname');
      if (name != null) dbs.add(name as String);
    });
    return dbs;
  }

  Future<void> switchDatabase(String newDbName) async {
    if (_host == null || newDbName == _dbName) return;
    _db?.close();
    _db = null;
    _isConnected = false;
    schemas = [];
    queryResult = null;
    await connect(
      host: _host!,
      port: _port!,
      dbName: newDbName,
      user: _user!,
      pwd: _pwd!,
      useSSL: _useSSL,
      allowClearTextPassword: _allowClearTextPassword,
    );
  }

  // ── Table context-menu actions ─────────────────────────────────────────────

  /// Returns the row count for [table] without touching the results panel.
  Future<int?> countTableRecords(TableItem table) async {
    if (_db == null) return null;
    try {
      final res = await _db!
          .select('SELECT count(*) AS c FROM ${table.fullName}');
      if (res == null || res.length == 0) return 0;
      return (res.first.get('c') as num?)?.toInt() ?? 0;
    } catch (_) {
      return null;
    }
  }

  /// Puts a SELECT * template in the active editor (not run).
  void insertSelectStatement(TableItem table) {
    _setEditorText('SELECT *\nFROM ${table.fullName};');
  }

  /// Puts an INSERT template with all columns in the active editor (not run).
  Future<void> insertInsertStatement(TableItem table) async {
    if (_db == null) return;
    await loadTableColumns(table);
    final cols = table.columns;
    if (cols == null || cols.isEmpty) {
      _setEditorText('INSERT INTO ${table.fullName}\nVALUES ();');
      return;
    }
    final colNames = cols.map((c) => '  ${c.name}').join(',\n');
    final values = cols.map((c) {
      if (c.isPrimaryKey) return '  DEFAULT                -- ${c.name} ${c.type}';
      if (c.isGeometry) {
        final srid = c.srid != null ? ', ${c.srid}' : '';
        return "  ST_GeomFromText('${c.geometryType ?? 'GEOMETRY'}()'$srid)  -- ${c.name}";
      }
      return '  null                   -- ${c.name} ${c.type}';
    }).join(',\n');
    _setEditorText(
        'INSERT INTO ${table.fullName} (\n$colNames\n)\nVALUES (\n$values\n);');
  }

  /// Puts a SELECT that produces INSERT statements in the active editor (not run).
  Future<void> insertGenerateInserts(TableItem table) async {
    if (_db == null) return;
    await loadTableColumns(table);
    final cols = table.columns;
    if (cols == null || cols.isEmpty) return;
    final colNames = cols.map((c) => c.name).join(', ');
    final valParts = cols.map((c) {
      if (c.isGeometry) {
        final srid = c.srid != null ? ', ${c.srid}' : '';
        return "  COALESCE('ST_GeomFromText(' || quote_literal(ST_AsText(${c.name})) || '$srid)', 'NULL')";
      }
      return '  quote_nullable(${c.name}::text)';
    });
    final valExpr = valParts.join(" ||\n  ', ' ||\n");
    _setEditorText("SELECT\n"
        "  'INSERT INTO ${table.fullName} ($colNames) VALUES (' ||\n"
        "$valExpr ||\n"
        "  ')'\n"
        "FROM ${table.fullName};");
  }

  /// Puts a DROP TABLE statement in the active editor (not run).
  void insertDropStatement(TableItem table) {
    _setEditorText('DROP TABLE IF EXISTS ${table.fullName};');
  }

  /// Fetches up to [limit] geometry WKTs from the table's geometry column.
  Future<List<String>> getTableGeometryWkts(TableItem table,
      {int limit = 500}) async {
    if (_db == null) return [];
    await loadTableColumns(table);
    String? geomColName;
    for (final c in table.columns ?? []) {
      if (c.isGeometry) {
        geomColName = c.name;
        break;
      }
    }
    if (geomColName == null) return [];
    final res = await _db!.select(
      'SELECT ST_AsText($geomColName) AS wkt FROM ${table.fullName} '
      'WHERE $geomColName IS NOT NULL LIMIT $limit',
    );
    final wkts = <String>[];
    res?.forEach((dynamic row) {
      final w = row.get('wkt') as String?;
      if (w != null) wkts.add(w);
    });
    return wkts;
  }

  void _setEditorText(String sql) {
    final ctrl = editors[activeEditorIndex];
    ctrl.text = sql;
    ctrl.selection = TextSelection.collapsed(offset: sql.length);
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
    final schema = table.schema;
    final tname = table.name;

    // ── Geometry info ──────────────────────────────────────────────────────
    String? geomColName;
    String? geomTypeName;
    int? geomSrid;
    bool hasSpatialIndex = false;
    if (table.isGeometry) {
      final gc = await _db!.getGeometryColumnsForTable(table.tableName);
      if (gc != null) {
        geomColName = gc.geometryColumnName;
        geomTypeName = gc.geometryType.typeName;
        geomSrid = gc.srid;
        hasSpatialIndex = gc.isSpatialIndexEnabled != 0;
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
        srid: isGeomCol ? geomSrid : null,
        hasSpatialIndex: isGeomCol && hasSpatialIndex,
      );
    }).toList();

    // ── Indexes (excluding PK) ─────────────────────────────────────────────
    final idxRes = await _db!.select("""
      SELECT i.relname AS iname, pg_get_indexdef(ix.indexrelid) AS idef,
             ix.indisunique AS is_unique
      FROM pg_index ix
      JOIN pg_class t  ON t.oid  = ix.indrelid
      JOIN pg_class i  ON i.oid  = ix.indexrelid
      JOIN pg_namespace n ON t.relnamespace = n.oid
      WHERE t.relname = '$tname' AND n.nspname = '$schema'
        AND NOT ix.indisprimary
      ORDER BY i.relname
    """);
    final idxList = <IndexInfo>[];
    idxRes?.forEach((dynamic row) {
      final def = (row.get('idef') as String? ?? '');
      final typeMatch = RegExp(r'USING (\w+)').firstMatch(def);
      final colMatch = RegExp(r'\(([^)]+)\)\s*$').firstMatch(def);
      idxList.add(IndexInfo(
        name: row.get('iname') as String? ?? '',
        type: typeMatch?.group(1) ?? 'btree',
        columns: colMatch?.group(1) ?? '',
        isUnique: row.get('is_unique') as bool? ?? false,
      ));
    });
    table.indexes = idxList;

    // ── Foreign keys ───────────────────────────────────────────────────────
    final fkRes = await _db!.select("""
      SELECT
        a.attname  AS col,
        nf.nspname AS ref_schema,
        cf.relname AS ref_table,
        af.attname AS ref_col
      FROM pg_constraint c
      JOIN pg_class     ct ON ct.oid = c.conrelid
      JOIN pg_namespace nt ON nt.oid = ct.relnamespace
      JOIN pg_attribute  a ON  a.attrelid = ct.oid AND a.attnum = ANY(c.conkey)
      JOIN pg_class     cf ON cf.oid = c.confrelid
      JOIN pg_namespace nf ON nf.oid = cf.relnamespace
      JOIN pg_attribute af ON af.attrelid = cf.oid AND af.attnum = ANY(c.confkey)
      WHERE c.contype = 'f'
        AND ct.relname = '$tname' AND nt.nspname = '$schema'
      ORDER BY a.attname
    """);
    final fkList = <ForeignKeyInfo>[];
    fkRes?.forEach((dynamic row) {
      fkList.add(ForeignKeyInfo(
        column: row.get('col') as String? ?? '',
        refSchema: row.get('ref_schema') as String? ?? '',
        refTable: row.get('ref_table') as String? ?? '',
        refColumn: row.get('ref_col') as String? ?? '',
      ));
    });
    table.foreignKeys = fkList;

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

    sql = '$sql\nLIMIT 100';
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
