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
        if (_expanded && table.columns != null)
          ...table.columns!
              .map((c) => _ColumnRow(col: c, indent: widget.indent + 16)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _shortType(col.type),
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF5C6BC0),
                  fontFamily: 'monospace'),
            ),
          ),
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
