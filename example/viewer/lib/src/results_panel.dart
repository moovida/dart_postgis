import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'wkb_to_wkt.dart';

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
          const Divider(height: 1, color: Color(0xFFDDDDEE)),
          Expanded(child: _ResultsBody(result: state.queryResult)),
        ],
      ),
    );
  }
}

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
          const Text(
            'Results',
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFF424242),
                fontWeight: FontWeight.w500),
          ),
          if (executing) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
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

class _ResultsBody extends StatelessWidget {
  final ViewerResult? result;

  const _ResultsBody({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const Center(
        child: Text(
          'Run a query to see results here.',
          style: TextStyle(color: Color(0xFFBBBBCC), fontSize: 12),
        ),
      );
    }

    if (result!.isError) {
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
            result!.rows.isNotEmpty ? result!.rows.first.first.toString() : '',
            style: const TextStyle(
              color: Color(0xFFB71C1C),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (result!.columns.isEmpty) {
      return const Center(
        child: Text('Query executed successfully.',
            style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12)),
      );
    }

    final columns = result!.columns;
    final rows = result!.rows;

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 10,
      minWidth: columns.length * 140.0,
      headingRowHeight: 32,
      dataRowHeight: 28,
      headingRowColor: WidgetStateProperty.all(const Color(0xFFEEF2FF)),
      border: TableBorder(
        horizontalInside:
            BorderSide(color: const Color(0xFFDDE4F5), width: 0.5),
        top: BorderSide(color: const Color(0xFFDDE4F5), width: 0.5),
        bottom: BorderSide(color: const Color(0xFFDDE4F5), width: 0.5),
      ),
      columns: columns
          .map(
            (col) => DataColumn2(
              label: Text(
                col,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
              size: ColumnSize.M,
            ),
          )
          .toList(),
      rows: rows.map((row) {
        return DataRow2(
          cells: List.generate(columns.length, (ci) {
            final raw = ci < row.length ? row[ci] : null;
            final rawStr = raw?.toString();
            final wkt = rawStr != null ? wkbHexToWkt(rawStr) : null;
            final full = wkt ?? rawStr;
            final display = _format(raw, wkt);
            final needsTooltip =
                full != null && display.length < full.length;
            return DataCell(
              needsTooltip
                  ? Tooltip(
                      message: full,
                      textStyle: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace'),
                      child: _CellText(display),
                    )
                  : _CellText(display),
            );
          }),
        );
      }).toList(),
    );
  }

  String _format(dynamic value, String? wkt) {
    if (value == null) return 'NULL';
    final s = wkt ?? value.toString();
    if (s.length > 80) return '${s.substring(0, 77)}…';
    return s;
  }
}

class _CellText extends StatelessWidget {
  final String text;
  const _CellText(this.text);

  @override
  Widget build(BuildContext context) {
    final isNull = text == 'NULL';
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        color: isNull ? const Color(0xFFBBBBCC) : const Color(0xFF212121),
        fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
