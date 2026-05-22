import 'package:flutter/material.dart';
import 'query_history.dart';

/// Result returned by [HistoryDialog]: the chosen SQL and whether to run it.
typedef HistoryResult = ({String sql, bool run});

class HistoryDialog extends StatefulWidget {
  final List<String> history;
  final Future<void> Function(String sql) onRemove;
  const HistoryDialog({
    super.key,
    required this.history,
    required this.onRemove,
  });

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  late List<String> _history;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _history = List.of(widget.history);
  }

  String get _selectedSql =>
      _history.isEmpty ? '' : _history[_selected];

  Future<void> _remove(int i) async {
    final sql = _history[i];
    await QueryHistory.remove(sql);
    widget.onRemove(sql);           // update AppState
    setState(() {
      _history.removeAt(i);
      if (_selected >= _history.length) _selected = _history.length - 1;
      if (_selected < 0) _selected = 0;
    });
  }

  void _use() => Navigator.of(context).pop<HistoryResult>((sql: _selectedSql, run: false));
  void _run() => Navigator.of(context).pop<HistoryResult>((sql: _selectedSql, run: true));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 680,
        height: 520,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Query History (${_history.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: _history.isEmpty
                  ? const Center(
                      child: Text(
                        'No queries recorded yet.',
                        style:
                            TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (_, i) {
                        final sql = _history[i];
                        final isSelected = i == _selected;
                        final preview = sql
                            .replaceAll(RegExp(r'\s+'), ' ')
                            .trim();
                        return InkWell(
                          onTap: () => setState(() => _selected = i),
                          onDoubleTap: () {
                            setState(() => _selected = i);
                            _run();
                          },
                          child: Container(
                            color: isSelected
                                ? const Color(0xFF1565C0)
                                : i.isOdd
                                    ? const Color(0xFFF5F7FF)
                                    : Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${i + 1}.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected
                                          ? Colors.white70
                                          : const Color(0xFF9E9E9E),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF212121),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _remove(i),
                                  icon: const Icon(Icons.close, size: 14),
                                  color: isSelected
                                      ? Colors.white70
                                      : const Color(0xFFBBBBCC),
                                  hoverColor: Colors.transparent,
                                  splashRadius: 12,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 24, minHeight: 24),
                                  tooltip: 'Remove from history',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 1, color: Color(0xFFDDDDEE)),

            // ── Preview ──────────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF8F9FF),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _selectedSql,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF212121),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFDDDDEE)),

            // ── Footer ───────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close',
                        style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _history.isEmpty ? null : _use,
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Use in editor',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _history.isEmpty ? null : _run,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Run', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
