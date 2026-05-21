import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class SqlEditorPanel extends StatefulWidget {
  const SqlEditorPanel({super.key});

  @override
  State<SqlEditorPanel> createState() => _SqlEditorPanelState();
}

class _SqlEditorPanelState extends State<SqlEditorPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<AppState>().setActiveEditor(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Tab bar + action buttons
          Container(
            color: const Color(0xFFEEF2FF),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF1565C0),
                    unselectedLabelColor: const Color(0xFF757575),
                    indicatorColor: const Color(0xFF1565C0),
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(fontSize: 12),
                    tabs: List.generate(
                      5,
                      (i) => Tab(text: 'Editor ${i + 1}', height: 34),
                    ),
                  ),
                ),
                // Limit controls
                _LimitControls(state: state),
                const SizedBox(width: 8),
                // Clear button
                _ToolbarBtn(
                  icon: Icons.clear,
                  label: 'Clear',
                  color: const Color(0xFF757575),
                  onPressed: () =>
                      state.editors[state.activeEditorIndex].clear(),
                ),
                const SizedBox(width: 4),
                // Run button
                _ToolbarBtn(
                  icon: Icons.play_arrow,
                  label: 'Run',
                  color: const Color(0xFF2E7D32),
                  onPressed:
                      state.isExecuting ? null : () => state.executeQuery(),
                  loading: state.isExecuting,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDDDDEE)),
          // Editor area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(
                5,
                (i) => _EditorTab(
                  controller: state.editors[i],
                  isActive: state.activeEditorIndex == i,
                  onRun: state.executeQuery,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorTab extends StatelessWidget {
  final TextEditingController controller;
  final bool isActive;
  final VoidCallback onRun;

  const _EditorTab({
    required this.controller,
    required this.isActive,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final text = details.data;
        final sel = controller.selection;
        final current = controller.text;
        final pos = (sel.isValid && sel.baseOffset >= 0)
            ? sel.baseOffset
            : current.length;
        controller.text =
            current.substring(0, pos) + text + current.substring(pos);
        controller.selection =
            TextSelection.collapsed(offset: pos + text.length);
      },
      builder: (context, candidateData, _) {
        return Container(
          decoration: candidateData.isNotEmpty
              ? BoxDecoration(
                  border:
                      Border.all(color: const Color(0xFF1565C0), width: 2),
                )
              : null,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  onRun,
              const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                  onRun,
            },
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF212121),
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                fillColor: Colors.white,
                filled: true,
                hintText: 'Enter SQL query… (Ctrl+Enter to run)',
                hintStyle: TextStyle(
                  color: Color(0xFFBBBBCC),
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
              cursorColor: const Color(0xFF1565C0),
            ),
          ),
        );
      },
    );
  }
}

class _LimitControls extends StatelessWidget {
  final AppState state;
  const _LimitControls({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: state.applyLimit,
          onChanged: (v) {
            state.applyLimit = v ?? true;
            // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
            state.notifyListeners();
          },
          side: const BorderSide(color: Color(0xFFBBBBCC)),
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? const Color(0xFF1565C0)
                  : Colors.transparent),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const Text('Limit',
            style: TextStyle(fontSize: 12, color: Color(0xFF616161))),
        const SizedBox(width: 4),
        SizedBox(
          width: 64,
          height: 28,
          child: TextField(
            controller: TextEditingController(text: '${state.queryLimit}')
              ..selection = TextSelection.collapsed(
                  offset: '${state.queryLimit}'.length),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF212121),
                fontFamily: 'monospace'),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
            onSubmitted: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) {
                state.queryLimit = n;
              }
            },
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
