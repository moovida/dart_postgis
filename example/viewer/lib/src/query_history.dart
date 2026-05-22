import 'package:shared_preferences/shared_preferences.dart';

class QueryHistory {
  static const _key = 'query_history_v1';
  static const maxEntries = 20;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<List<String>> remove(String sql) async {
    final trimmed = sql.trim();
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_key) ?? []).toList();
    list.remove(trimmed);
    await prefs.setStringList(_key, list);
    return list;
  }

  /// Adds [sql] to the front, removes any duplicate, trims to [maxEntries].
  /// Returns the updated list.
  static Future<List<String>> add(String sql) async {
    final trimmed = sql.trim();
    if (trimmed.isEmpty) return load();
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_key) ?? []).toList();
    list.remove(trimmed);
    list.insert(0, trimmed);
    final updated = list.take(maxEntries).toList();
    await prefs.setStringList(_key, updated);
    return updated;
  }
}
