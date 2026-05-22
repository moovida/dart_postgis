import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'connection_history.dart';

class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController(text: 'localhost');
  final _portCtrl = TextEditingController(text: '5432');
  final _dbCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool _obscurePwd = true;
  bool _useSSL = true;
  bool _allowClearTextPassword = false;
  String? _error;
  bool _connecting = false;

  List<ConnectionRecord> _history = [];
  ConnectionRecord? _selectedRecord;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await ConnectionHistory.load();
    if (mounted) {
      setState(() => _history = records);
    }
  }

  void _applyRecord(ConnectionRecord r) {
    setState(() {
      _selectedRecord = r;
      _hostCtrl.text = r.host;
      _portCtrl.text = '${r.port}';
      _dbCtrl.text = r.dbName;
      _userCtrl.text = r.user;
      _pwdCtrl.text = r.pwd;
      _useSSL = r.useSSL;
      _allowClearTextPassword = r.allowClearTextPassword;
      _error = null;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedRecord == null) return;
    await ConnectionHistory.remove(_selectedRecord!);
    final records = await ConnectionHistory.load();
    setState(() {
      _history = records;
      _selectedRecord = null;
    });
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _connecting = true;
    });

    final record = ConnectionRecord(
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      dbName: _dbCtrl.text.trim(),
      user: _userCtrl.text.trim(),
      pwd: _pwdCtrl.text,
      useSSL: _useSSL,
      allowClearTextPassword: _allowClearTextPassword,
    );

    try {
      await context.read<AppState>().connect(
            host: record.host,
            port: record.port,
            dbName: record.dbName,
            user: record.user,
            pwd: record.pwd,
            useSSL: record.useSSL,
            allowClearTextPassword: record.allowClearTextPassword,
          );
      await ConnectionHistory.upsert(record);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _connecting = false;
      });
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _dbCtrl.dispose();
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 560,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    const Icon(Icons.storage,
                        color: Color(0xFF1565C0), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Connect to PostgreSQL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      color: const Color(0xFF9E9E9E),
                    ),
                  ],
                ),

                // Saved connections dropdown
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCCCCDD)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history,
                            size: 15, color: Color(0xFF5C6BC0)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ConnectionRecord>(
                              value: _selectedRecord,
                              hint: const Text(
                                'Saved connections…',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF757575)),
                              ),
                              isExpanded: true,
                              isDense: true,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF212121)),
                              dropdownColor: Colors.white,
                              items: _history
                                  .map((r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(
                                          '${r.label} (${r.user})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (r) {
                                if (r != null) _applyRecord(r);
                              },
                            ),
                          ),
                        ),
                        if (_selectedRecord != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: _deleteSelected,
                            icon: const Icon(Icons.delete_outline, size: 16),
                            color: const Color(0xFFB71C1C),
                            tooltip: 'Remove saved connection',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                // Host + Port
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _Field(
                        label: 'Host',
                        controller: _hostCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Port',
                        controller: _portCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final p = int.tryParse(v.trim());
                          if (p == null || p < 1 || p > 65535) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Database',
                  controller: _dbCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'User',
                  controller: _userCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pwdCtrl,
                  obscureText: _obscurePwd,
                  style: const TextStyle(
                      color: Color(0xFF212121), fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePwd
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: const Color(0xFF9E9E9E),
                      ),
                      onPressed: () =>
                          setState(() => _obscurePwd = !_obscurePwd),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // SSL + clear-text password toggles
                Row(
                  children: [
                    Checkbox(
                      value: _useSSL,
                      onChanged: (v) => setState(() => _useSSL = v ?? true),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Text('Use SSL',
                        style: TextStyle(fontSize: 13, color: Color(0xFF424242))),
                    const SizedBox(width: 16),
                    Checkbox(
                      value: _allowClearTextPassword,
                      onChanged: (v) =>
                          setState(() => _allowClearTextPassword = v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Text('Allow plain-text password',
                        style: TextStyle(fontSize: 13, color: Color(0xFF424242))),
                  ],
                ),
                // Error box
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFEF9A9A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFB71C1C), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _cleanError(_error!),
                                style: const TextStyle(
                                    color: Color(0xFFB71C1C), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (_errorHint(_error!) != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Text(
                              _errorHint(_error!)!,
                              style: const TextStyle(
                                  color: Color(0xFFB71C1C),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _connecting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _connecting ? null : _connect,
                      icon: _connecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.link, size: 16),
                      label: Text(_connecting ? 'Connecting…' : 'Connect'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Strips verbose prefix: "PostgreSQLSeverity.fatal 28P01: foo" → "foo (28P01)"
  static String _cleanError(String raw) {
    final m = RegExp(r'PostgreSQLSeverity\.\w+ (\w+): (.+)', dotAll: true)
        .firstMatch(raw);
    if (m != null) return '${m.group(2)} [${m.group(1)}]';
    return raw;
  }

  static String? _errorHint(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('28p01') || lower.contains('password authentication')) {
      return 'Wrong password, or the server uses SCRAM-SHA-256 with TLS channel '
          'binding (scram-sha-256-plus) which the client library does not support. '
          'Server-side fix: add channel_binding = disable to postgresql.conf.';
    }
    if (lower.contains('ssl') || lower.contains('certificate')) {
      return 'SSL handshake failed. Try disabling "Use SSL" if the server '
          'does not require encrypted connections.';
    }
    if (lower.contains('timeout') || lower.contains('connection refused')) {
      return 'Cannot reach the server. Check the host, port, and firewall rules.';
    }
    if (lower.contains('28000') || lower.contains('not permitted')) {
      return 'User not allowed from this host — check pg_hba.conf on the server.';
    }
    return null;
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: Color(0xFF212121), fontSize: 13),
      decoration: InputDecoration(labelText: label),
    );
  }
}
