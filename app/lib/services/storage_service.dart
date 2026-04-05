import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/serial_item.dart';

class SessionData {
  final String name;
  final List<SerialItem> items;

  SessionData({required this.name, required this.items});
}

class StorageService {
  static const _keyName = 'session_name';
  static const _keyItems = 'session_items';

  Future<void> saveSession(String name, List<SerialItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    final json = jsonEncode(items.map((i) => i.toFullMap()).toList());
    await prefs.setString(_keyItems, json);
  }

  Future<SessionData?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyName);
    final itemsJson = prefs.getString(_keyItems);

    if (name == null || itemsJson == null) return null;

    final List<dynamic> decoded = jsonDecode(itemsJson);
    final items = decoded
        .map((m) => SerialItem.fromMap(m as Map<String, dynamic>))
        .toList();

    return SessionData(name: name, items: items);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyItems);
  }
}
