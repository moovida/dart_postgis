import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'db_viewer_page.dart';

/// Optional connection parameters for [DbViewerWidget].
/// When provided the widget connects automatically on first build.
class DbViewerConnectionParams {
  final String host;
  final int port;
  final String dbName;
  final String user;
  final String pwd;
  final bool useSSL;
  final bool allowClearTextPassword;

  const DbViewerConnectionParams({
    required this.host,
    required this.port,
    required this.dbName,
    required this.user,
    required this.pwd,
    this.useSSL = true,
    this.allowClearTextPassword = false,
  });
}

/// A self-contained PostGIS viewer widget.
///
/// Creates and owns its own [AppState] and [ChangeNotifierProvider], so it
/// can be dropped into any widget tree that already has a [MaterialApp]
/// ancestor — no extra provider setup required.
///
/// ```dart
/// // Standalone (user opens connection dialog manually):
/// DbViewerWidget()
///
/// // With pre-filled connection (auto-connects on load):
/// DbViewerWidget(
///   connectionParams: DbViewerConnectionParams(
///     host: 'localhost', port: 5432,
///     dbName: 'mydb', user: 'postgres', pwd: 'secret',
///   ),
/// )
/// ```
class DbViewerWidget extends StatefulWidget {
  /// Optional connection to open automatically on first build.
  final DbViewerConnectionParams? connectionParams;

  /// Title shown in the blue toolbar.
  final String title;

  const DbViewerWidget({
    super.key,
    this.connectionParams,
    this.title = 'G-ANT DB Viewer',
  });

  @override
  State<DbViewerWidget> createState() => _DbViewerWidgetState();
}

class _DbViewerWidgetState extends State<DbViewerWidget> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    final p = widget.connectionParams;
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _appState.connect(
          host: p.host,
          port: p.port,
          dbName: p.dbName,
          user: p.user,
          pwd: p.pwd,
          useSSL: p.useSSL,
          allowClearTextPassword: p.allowClearTextPassword,
        );
      });
    }
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: DbViewerPage(title: widget.title),
    );
  }
}
