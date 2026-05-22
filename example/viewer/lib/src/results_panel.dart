import 'dart:math' show min, max;
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'geometry_preview.dart';
import 'wkb_to_wkt.dart' show wkbToWkt;

class ResultsPanel extends StatelessWidget {
  const ResultsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _PanelHeader(result: state.queryResult, executing: state.isExecuting),
          _FormatDatesBar(state: state),
          const Divider(height: 1, color: Color(0xFFDDDDEE)),
          Expanded(
            child: _ResultsBody(
              result: state.queryResult,
              formatDates: state.formatDates,
              datePatterns: state.datePatterns,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final ViewerResult? result;
  final bool executing;
  const _PanelHeader({required this.result, required this.executing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: const Color(0xFFE8EFF7),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.table_rows, size: 14, color: Color(0xFF1565C0)),
          const SizedBox(width: 6),
          const Text('Results',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF424242),
                  fontWeight: FontWeight.w500)),
          if (executing) ...[
            const SizedBox(width: 10),
            const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 6),
            const Text('Executing…',
                style: TextStyle(fontSize: 11, color: Color(0xFF616161))),
          ] else if (result != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: result!.isError
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                result!.isError
                    ? 'Error'
                    : '${result!.rows.length} rows · ${result!.elapsedMs} ms',
                style: TextStyle(
                  fontSize: 11,
                  color: result!.isError
                      ? const Color(0xFFB71C1C)
                      : const Color(0xFF1B5E20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Format-dates control bar ──────────────────────────────────────────────────

class _FormatDatesBar extends StatefulWidget {
  final AppState state;
  const _FormatDatesBar({required this.state});

  @override
  State<_FormatDatesBar> createState() => _FormatDatesBarState();
}

class _FormatDatesBarState extends State<_FormatDatesBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.datePatterns);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Container(
      height: 30,
      color: const Color(0xFFF5F7FF),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: state.formatDates,
              onChanged: (v) => state.setFormatDates(v ?? false),
              side: const BorderSide(color: Color(0xFFBBBBCC)),
              fillColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected)
                      ? const Color(0xFF1565C0)
                      : Colors.transparent),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          const Text('Format dates',
              style: TextStyle(fontSize: 11, color: Color(0xFF616161))),
          const SizedBox(width: 10),
          const Text('patterns',
              style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
            height: 22,
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFF212121)),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFCCCCDD))),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFCCCCDD))),
                focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Color(0xFF1565C0), width: 1.5)),
                isDense: true,
              ),
              onChanged: state.setDatePatterns,
              onSubmitted: state.setDatePatterns,
            ),
          ),
          ),
        ],
      ),
    );
  }
}

// ── Pre-computed per-cell data (built once per result, not per frame) ─────────

class _CellData {
  final String display;
  final String? wkt;  // non-null → geometry cell
  final String? tip;  // non-null → display was truncated, tip holds full text
  const _CellData({required this.display, this.wkt, this.tip});
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ResultsBody extends StatefulWidget {
  final ViewerResult? result;
  final bool formatDates;
  final String datePatterns;
  const _ResultsBody({
    required this.result,
    required this.formatDates,
    required this.datePatterns,
  });

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> {
  static const _defaultColW = 150.0;
  static const _minColW = 40.0;
  static const _hMargin = 8.0;

  // Const text styles — avoids creating new TextStyle objects on every build
  static const _styleNormal = TextStyle(
      fontSize: 12, fontFamily: 'monospace', color: Color(0xFF212121));
  static const _styleNull = TextStyle(
      fontSize: 12,
      fontFamily: 'monospace',
      color: Color(0xFFBBBBCC),
      fontStyle: FontStyle.italic);

  List<double> _colWidths = [];
  List<String> _lastColumns = [];

  // Cell data cache — rebuilt once per result, not per frame
  List<List<_CellData>> _cache = [];
  ViewerResult? _cachedResult;

  // Multi-cell selection: (rowIndex, colIndex)
  final Set<(int, int)> _selected = {};
  (int, int)? _lastTapped;

  @override
  void initState() {
    super.initState();
    _rebuildCache(widget.result);
  }

  @override
  void didUpdateWidget(_ResultsBody old) {
    super.didUpdateWidget(old);
    final cols = widget.result?.columns ?? [];
    if (cols.length != _lastColumns.length ||
        cols.join('\x00') != _lastColumns.join('\x00')) {
      _initWidths(cols);
    }
    if (!identical(widget.result, _cachedResult) ||
        widget.formatDates != old.formatDates ||
        widget.datePatterns != old.datePatterns) {
      _rebuildCache(widget.result);
    }
  }

  void _initWidths(List<String> cols) {
    _lastColumns = List.of(cols);
    _colWidths = List.filled(cols.length, _defaultColW);
    _selected.clear();
    _lastTapped = null;
  }

  /// Builds the cell cache from the result. Called once per new result.
  void _rebuildCache(ViewerResult? result) {
    _cachedResult = result;
    if (result == null || result.isError || result.columns.isEmpty) {
      _cache = [];
      return;
    }

    // Pre-compute which columns should be formatted as epoch dates.
    final dateCols = <int>{};
    if (widget.formatDates) {
      final pats = widget.datePatterns
          .split(',')
          .map((p) => p.trim().toLowerCase())
          .where((p) => p.isNotEmpty)
          .toList();
      for (int ci = 0; ci < result.columns.length; ci++) {
        final col = result.columns[ci].toLowerCase();
        if (pats.any((p) => col.contains(p))) dateCols.add(ci);
      }
    }

    final rows = result.rows;
    final numCols = result.columns.length;
    _cache = List.generate(rows.length, (ri) {
      return List.generate(numCols, (ci) {
        final raw = ci < rows[ri].length ? rows[ri][ci] : null;
        final wkt = wkbToWkt(raw);
        final dateStr =
            (dateCols.contains(ci) && raw is int) ? _epochToString(raw) : null;
        final full = dateStr ?? wkt ?? raw?.toString();
        final display = _formatCell(raw, wkt, dateStr);
        final tip =
            (wkt == null && dateStr == null && full != null && display.length < full.length)
                ? full
                : null;
        return _CellData(display: display, wkt: wkt, tip: tip);
      });
    });
  }

  static String _formatCell(dynamic value, String? wkt, String? dateStr) {
    if (value == null) return 'NULL';
    if (dateStr != null) return dateStr;
    final s = wkt ?? value.toString();
    if (s.length > 80) return '${s.substring(0, 77)}…';
    return s;
  }

  static String _epochToString(int v) {
    final ms = v > 10000000000 ? v : v * 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
    return '${p(dt.year, 4)}-${p(dt.month)}-${p(dt.day)} '
        '${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    if (result == null) {
      return const Center(
        child: Text('Run a query to see results here.',
            style: TextStyle(color: Color(0xFFBBBBCC), fontSize: 12)),
      );
    }

    if (result.isError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFEF9A9A)),
          ),
          child: SelectableText(
            result.rows.isNotEmpty
                ? result.rows.first.first.toString()
                : '',
            style: const TextStyle(
                color: Color(0xFFB71C1C),
                fontFamily: 'monospace',
                fontSize: 12),
          ),
        ),
      );
    }

    if (result.columns.isEmpty) {
      return const Center(
        child: Text('Query executed successfully.',
            style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12)),
      );
    }

    final columns = result.columns;
    final rows = result.rows;
    if (_colWidths.length != columns.length) _initWidths(columns);

    // One MouseRegion covers all cells; resize-handle MouseRegions in headers
    // override it locally via the standard Flutter hit-test cascade.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: DataTable2(
        columnSpacing: 0,
        horizontalMargin: _hMargin,
        minWidth: _colWidths.fold<double>(0.0, (s, w) => s + w) + 2 * _hMargin + 1,
        headingRowHeight: 32,
        dataRowHeight: 28,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFEEF2FF)),
        border: TableBorder.all(color: const Color(0xFFD4DCF0), width: 0.5),
        columns: List.generate(columns.length, (i) => _buildColumn(context, i, columns[i])),
        rows: List.generate(rows.length, (ri) {
          final rowCache = ri < _cache.length ? _cache[ri] : const <_CellData>[];
          return DataRow2(
            cells: List.generate(columns.length, (ci) {
              final cd = ci < rowCache.length
                  ? rowCache[ci]
                  : const _CellData(display: '');
              return DataCell(_buildCell(context, ri, ci, cd));
            }),
          );
        }),
      ),
    );
  }

  // ── Column header with resize handle ──────────────────────────────────────

  DataColumn2 _buildColumn(BuildContext ctx, int i, String name) {
    return DataColumn2(
      fixedWidth: _colWidths[i],
      label: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (e) =>
            _onColumnRightClick(ctx, e.globalPosition, i),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  )),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => setState(
                    () => _colWidths[i] = max(_minColW, _colWidths[i] + d.delta.dx)),
                child: Container(
                  width: 7,
                  height: 32,
                  decoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(color: Color(0xFFCCCCDD), width: 1)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onColumnRightClick(BuildContext ctx, Offset pos, int ci) {
    final colWkts = <String>[];
    final colValues = <String>[];
    for (int ri = 0; ri < _cache.length; ri++) {
      if (ci < _cache[ri].length) {
        final cd = _cache[ri][ci];
        colValues.add(cd.tip ?? cd.wkt ?? cd.display);
        if (cd.wkt != null) colWkts.add(cd.wkt!);
      }
    }
    final hasGeom = colWkts.isNotEmpty;

    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        PopupMenuItem(
          value: 'copy',
          height: 36,
          child: Row(children: [
            const Icon(Icons.copy, size: 14, color: Color(0xFF424242)),
            const SizedBox(width: 8),
            Text('Copy ${colValues.length} values',
                style: const TextStyle(fontSize: 13)),
          ]),
        ),
        if (hasGeom)
          PopupMenuItem(
            value: 'view',
            height: 36,
            child: Row(children: [
              const Icon(Icons.place, size: 14, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text('View ${colWkts.length} geometries',
                  style: const TextStyle(fontSize: 13)),
            ]),
          ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: colValues.join('\n')));
      } else if (value == 'view') {
        showDialog(
          context: context,
          builder: (_) => GeometryPreviewDialog(wkts: colWkts),
        );
      }
    });
  }

  // ── Cell ──────────────────────────────────────────────────────────────────

  Widget _buildCell(BuildContext ctx, int ri, int ci, _CellData cd) {
    final isSelected = _selected.contains((ri, ci));

    Widget inner = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(ri, ci),
      onSecondaryTapUp: (e) =>
          _onRightClick(ctx, e.globalPosition, ri, ci, cd),
      child: Container(
        width: double.infinity,
        color: isSelected ? const Color(0x281565C0) : null,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        child: Text(
          cd.display,
          overflow: TextOverflow.ellipsis,
          style: cd.display == 'NULL' ? _styleNull : _styleNormal,
        ),
      ),
    );

    if (cd.tip != null) {
      inner = Tooltip(
        message: cd.tip!,
        textStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        child: inner,
      );
    }

    return inner;
  }

  // ── Selection logic ───────────────────────────────────────────────────────

  void _onTap(int ri, int ci) {
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    setState(() {
      if (shift && _lastTapped != null) {
        final r0 = min(_lastTapped!.$1, ri);
        final r1 = max(_lastTapped!.$1, ri);
        final c0 = min(_lastTapped!.$2, ci);
        final c1 = max(_lastTapped!.$2, ci);
        for (int r = r0; r <= r1; r++) {
          for (int c = c0; c <= c1; c++) {
            _selected.add((r, c));
          }
        }
      } else if (ctrl) {
        if (!_selected.remove((ri, ci))) _selected.add((ri, ci));
        _lastTapped = (ri, ci);
      } else {
        _selected
          ..clear()
          ..add((ri, ci));
        _lastTapped = (ri, ci);
      }
    });
  }

  void _onRightClick(
      BuildContext ctx, Offset pos, int ri, int ci, _CellData cd) {
    if (!_selected.contains((ri, ci))) {
      setState(() {
        _selected
          ..clear()
          ..add((ri, ci));
        _lastTapped = (ri, ci);
      });
    }

    final n = _selected.length;
    final copyLabel = n > 1 ? 'Copy $n cells' : 'Copy';
    final toCopy = n > 1 ? _selectedAsTsv() : (cd.tip ?? cd.wkt ?? cd.display);

    final selectedWkts = _selectedGeomWkts();
    final hasGeom = selectedWkts.isNotEmpty;
    final geomLabel = selectedWkts.length > 1
        ? 'View ${selectedWkts.length} geometries'
        : 'View geometry';

    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        PopupMenuItem(
          value: 'copy',
          height: 36,
          child: Row(children: [
            const Icon(Icons.copy, size: 14, color: Color(0xFF424242)),
            const SizedBox(width: 8),
            Text(copyLabel, style: const TextStyle(fontSize: 13)),
          ]),
        ),
        if (hasGeom)
          PopupMenuItem(
            value: 'view',
            height: 36,
            child: Row(children: [
              const Icon(Icons.place, size: 14, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(geomLabel, style: const TextStyle(fontSize: 13)),
            ]),
          ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: toCopy));
      } else if (value == 'view' && hasGeom) {
        showDialog(
          context: context,
          builder: (_) => GeometryPreviewDialog(wkts: selectedWkts),
        );
      }
    });
  }

  /// WKT strings for every selected geometry cell — reads from cache, no reparse.
  List<String> _selectedGeomWkts() {
    final wkts = <String>[];
    for (final (r, c) in _selected) {
      if (r < _cache.length && c < _cache[r].length) {
        final w = _cache[r][c].wkt;
        if (w != null) wkts.add(w);
      }
    }
    return wkts;
  }

  /// TSV of the current selection — reads from cache, no reparse.
  String _selectedAsTsv() {
    final byRow = <int, List<int>>{};
    for (final (r, c) in _selected) {
      byRow.putIfAbsent(r, () => []).add(c);
    }
    return (byRow.keys.toList()..sort())
        .map((r) => (byRow[r]!..sort()).map((c) {
              if (r < _cache.length && c < _cache[r].length) {
                final cd = _cache[r][c];
                return cd.tip ?? cd.wkt ?? cd.display;
              }
              return '';
            }).join('\t'))
        .join('\n');
  }
}
