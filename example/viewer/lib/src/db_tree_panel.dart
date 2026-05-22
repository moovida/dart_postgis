import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class DbTreePanel extends StatelessWidget {
  const DbTreePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            label: state.isConnected ? state.connectionLabel : 'Not connected',
            icon: Icons.dns,
          ),
          Expanded(
            child: state.isConnected
                ? _SchemaTree(schemas: state.schemas)
                : const Center(
                    child: Text(
                      'Connect to a database\nto see the schema tree.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF9E9E9E), fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PanelHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFFE8EFF7),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1565C0)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF424242),
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemaTree extends StatelessWidget {
  final List<SchemaItem> schemas;
  const _SchemaTree({required this.schemas});

  @override
  Widget build(BuildContext context) {
    if (schemas.isEmpty) {
      return const Center(
        child: Text('No schemas found.',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
      );
    }
    return ListView.builder(
      itemCount: schemas.length,
      itemBuilder: (ctx, i) => _SchemaNode(schema: schemas[i]),
    );
  }
}

class _SchemaNode extends StatefulWidget {
  final SchemaItem schema;
  const _SchemaNode({required this.schema});

  @override
  State<_SchemaNode> createState() => _SchemaNodeState();
}

class _SchemaNodeState extends State<_SchemaNode> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.schema.name == 'public';
  }

  @override
  Widget build(BuildContext context) {
    final schema = widget.schema;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.folder_open : Icons.folder,
                  size: 15,
                  color: const Color(0xFFF57F17),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    schema.name,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF212121)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${schema.tables.length}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: const Color(0xFF9E9E9E),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...schema.tables.map((t) => _TableNode(table: t, indent: 16)),
      ],
    );
  }
}

class _TableNode extends StatefulWidget {
  final TableItem table;
  final double indent;
  const _TableNode({required this.table, required this.indent});

  @override
  State<_TableNode> createState() => _TableNodeState();
}

class _TableNodeState extends State<_TableNode> {
  bool _expanded = false;
  bool _loadingColumns = false;
  bool _runningQuery = false;

  Future<void> _toggleExpand() async {
    if (!_expanded && widget.table.columns == null) {
      setState(() => _loadingColumns = true);
      await context.read<AppState>().loadTableColumns(widget.table);
      if (mounted) setState(() => _loadingColumns = false);
    }
    if (mounted) setState(() => _expanded = !_expanded);
  }

  Future<void> _runQuery() async {
    if (_runningQuery) return;
    setState(() => _runningQuery = true);
    await context.read<AppState>().runTableSelectQuery(widget.table);
    if (mounted) setState(() => _runningQuery = false);
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final hasGeom = table.columns?.any((c) => c.isGeometry) ?? table.isGeometry;
    final busy = _loadingColumns || _runningQuery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Draggable<String>(
          data: table.fullName,
          feedback: _DragChip(table.fullName),
          childWhenDragging: Opacity(opacity: 0.4, child: _tableRow(hasGeom, busy)),
          child: _tableRow(hasGeom, busy),
        ),
        if (_expanded && table.columns != null) ...[
          ...table.columns!
              .map((c) => _ColumnRow(col: c, indent: widget.indent + 16)),
          if (table.indexes != null && table.indexes!.isNotEmpty)
            _SectionHeader(label: 'Indexes', indent: widget.indent + 16),
          ...?table.indexes?.map((idx) => _IndexRow(idx: idx, indent: widget.indent + 24)),
          if (table.foreignKeys != null && table.foreignKeys!.isNotEmpty)
            _SectionHeader(label: 'Foreign keys', indent: widget.indent + 16),
          ...?table.foreignKeys?.map((fk) => _FkRow(fk: fk, tableSchema: table.schema, indent: widget.indent + 24)),
        ],
      ],
    );
  }

  Widget _tableRow(bool hasGeom, bool busy) {
    final table = widget.table;
    return Padding(
      padding: EdgeInsets.only(left: widget.indent, right: 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _runQuery,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      hasGeom ? Icons.map : Icons.table_chart,
                      size: 14,
                      color: hasGeom
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        table.name,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF424242)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : InkWell(
                    onTap: _toggleExpand,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 3),
                      child: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 13,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ColumnRow extends StatelessWidget {
  final ColumnItem col;
  final double indent;
  const _ColumnRow({required this.col, required this.indent});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.only(left: indent, right: 8, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(
            col.isPrimaryKey
                ? Icons.key
                : col.isGeometry
                    ? Icons.place
                    : Icons.short_text,
            size: 12,
            color: col.isPrimaryKey
                ? const Color(0xFFF57F17)
                : col.isGeometry
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF9E9E9E),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              col.name,
              style: const TextStyle(fontSize: 11, color: Color(0xFF616161)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _chip(_shortType(col.type), const Color(0xFFEEF2FF), const Color(0xFF5C6BC0)),
          if (col.isGeometry && col.srid != null) ...[
            const SizedBox(width: 3),
            _chip('EPSG:${col.srid}', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
          ],
          if (col.isGeometry && col.hasSpatialIndex) ...[
            const SizedBox(width: 3),
            Tooltip(
              message: 'Spatial index',
              child: Icon(Icons.bolt, size: 11, color: const Color(0xFFF57F17)),
            ),
          ],
        ],
      ),
    );
    return Draggable<String>(
      data: col.name,
      feedback: _DragChip(col.name),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: fg, fontFamily: 'monospace')),
    );
  }

  String _shortType(String type) {
    const abbrev = {
      'character varying': 'varchar',
      'double precision': 'float8',
      'timestamp without time zone': 'timestamp',
      'timestamp with time zone': 'timestamptz',
    };
    return abbrev[type] ?? type;
  }
}

// ── Section header (Indexes / Foreign keys) ───────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final double indent;
  const _SectionHeader({required this.label, required this.indent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: 8, top: 4, bottom: 1),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontSize: 9,
            color: Color(0xFFAAAAAA),
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Index row ─────────────────────────────────────────────────────────────────

class _IndexRow extends StatelessWidget {
  final IndexInfo idx;
  final double indent;
  const _IndexRow({required this.idx, required this.indent});

  @override
  Widget build(BuildContext context) {
    final isGist = idx.type.toLowerCase() == 'gist';
    return Padding(
      padding: EdgeInsets.only(left: indent, right: 8, top: 1, bottom: 1),
      child: Row(
        children: [
          Icon(
            isGist ? Icons.map : Icons.sort,
            size: 11,
            color: isGist ? const Color(0xFF2E7D32) : const Color(0xFF78909C),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              idx.name,
              style: const TextStyle(fontSize: 11, color: Color(0xFF616161)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (idx.isUnique)
            const Tooltip(
              message: 'Unique',
              child: Icon(Icons.verified_outlined,
                  size: 11, color: Color(0xFF7B61FF)),
            ),
          const SizedBox(width: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              idx.columns,
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF9E9E9E),
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Foreign key row ───────────────────────────────────────────────────────────

class _FkRow extends StatelessWidget {
  final ForeignKeyInfo fk;
  final String tableSchema;
  final double indent;
  const _FkRow(
      {required this.fk, required this.tableSchema, required this.indent});

  @override
  Widget build(BuildContext context) {
    final ref = fk.refSchema == tableSchema
        ? '${fk.refTable}(${fk.refColumn})'
        : '${fk.refSchema}.${fk.refTable}(${fk.refColumn})';
    return Padding(
      padding: EdgeInsets.only(left: indent, right: 8, top: 1, bottom: 1),
      child: Row(
        children: [
          const Icon(Icons.call_made, size: 11, color: Color(0xFF5C6BC0)),
          const SizedBox(width: 4),
          Text(
            fk.column,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF616161),
                fontFamily: 'monospace'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward, size: 10, color: Color(0xFFBBBBCC)),
          ),
          Expanded(
            child: Text(
              ref,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF5C6BC0),
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DragChip extends StatelessWidget {
  final String label;
  const _DragChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
