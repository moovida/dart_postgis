import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionRecord {
  final String host;
  final int port;
  final String dbName;
  final String user;
  final String pwd;
  final bool useSSL;
  final bool allowClearTextPassword;

  const ConnectionRecord({
    required this.host,
    required this.port,
    required this.dbName,
    required this.user,
    required this.pwd,
    required this.useSSL,
    this.allowClearTextPassword = false,
  });

  String get label => '$host:$port/$dbName';

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'dbName': dbName,
        'user': user,
        'pwd': pwd,
        'useSSL': useSSL,
        'allowClearTextPassword': allowClearTextPassword,
      };

  factory ConnectionRecord.fromJson(Map<String, dynamic> j) => ConnectionRecord(
        host: j['host'] as String,
        port: j['port'] as int,
        dbName: j['dbName'] as String,
        user: j['user'] as String,
        pwd: j['pwd'] as String,
        useSSL: j['useSSL'] as bool? ?? true,
        allowClearTextPassword: j['allowClearTextPassword'] as bool? ?? false,
      );
}

class ConnectionHistory {
  static const _key = 'connection_history';

  static Future<List<ConnectionRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ConnectionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> upsert(ConnectionRecord record) async {
    final records = await load();
    // Replace existing entry with same host:port:db, otherwise prepend
    final idx = records.indexWhere((r) =>
        r.host == record.host &&
        r.port == record.port &&
        r.dbName == record.dbName);
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.insert(0, record);
    }
    await _persist(records);
  }

  static Future<void> remove(ConnectionRecord record) async {
    final records = await load();
    records.removeWhere((r) =>
        r.host == record.host &&
        r.port == record.port &&
        r.dbName == record.dbName);
    await _persist(records);
  }

  static Future<void> _persist(List<ConnectionRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(records.map((r) => r.toJson()).toList()));
  }
}
