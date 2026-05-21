import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'connection_dialog.dart';
import 'db_tree_panel.dart';
import 'results_panel.dart';
import 'sql_editor_panel.dart';

class DbViewerPage extends StatefulWidget {
  const DbViewerPage({super.key});

  @override
  State<DbViewerPage> createState() => _DbViewerPageState();
}

class _DbViewerPageState extends State<DbViewerPage> {
  final _hSplitController = MultiSplitViewController(
    areas: [Area(size: 280, minimalSize: 180), Area(weight: 1)],
  );
  final _vSplitController = MultiSplitViewController(
    areas: [Area(weight: 3, minimalSize: 120), Area(weight: 2, minimalSize: 80)],
  );

  @override
  void dispose() {
    _hSplitController.dispose();
    _vSplitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: Column(
        children: [
          _Toolbar(state: state),
          const Divider(height: 1, color: Color(0xFFCCCCDD)),
          Expanded(
            child: MultiSplitViewTheme(
              data: MultiSplitViewThemeData(
                dividerThickness: 5,
                dividerPainter: DividerPainters.background(
                  color: const Color(0xFFDDDDEE),
                  highlightedColor: const Color(0xFF1565C0),
                ),
              ),
              child: MultiSplitView(
                axis: Axis.horizontal,
                controller: _hSplitController,
                children: [
                  const DbTreePanel(),
                  MultiSplitView(
                    axis: Axis.vertical,
                    controller: _vSplitController,
                    children: [
                      const SqlEditorPanel(),
                      const ResultsPanel(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _StatusBar(status: state.status),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final AppState state;
  const _Toolbar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.storage, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'HydroGIS DB Viewer',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          if (state.isConnected) ...[
            const Icon(Icons.circle, color: Color(0xFF81C784), size: 10),
            const SizedBox(width: 6),
            Text(
              state.connectionLabel,
              style: const TextStyle(color: Color(0xFFBBDDFF), fontSize: 13),
            ),
          ],
          const Spacer(),
          if (state.isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          const SizedBox(width: 8),
          if (!state.isConnected)
            FilledButton.icon(
              onPressed: () => _showConnect(context),
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Connect'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1565C0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            )
          else ...[
            IconButton(
              onPressed: () => state.refreshTree(),
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh tree',
              color: Colors.white70,
            ),
            OutlinedButton.icon(
              onPressed: () => state.disconnect(),
              icon: const Icon(Icons.link_off, size: 16),
              label: const Text('Disconnect'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showConnect(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppState>(),
        child: const ConnectionDialog(),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String status;
  const _StatusBar({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      color: const Color(0xFFE8EFF7),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 13, color: Color(0xFF616161)),
          const SizedBox(width: 6),
          Text(
            status,
            style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
          ),
        ],
      ),
    );
  }
}
