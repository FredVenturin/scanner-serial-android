import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/batch.dart';

class StorageService {
  static const _keyBatches = 'batches';
  static const _keyLastBatchId = 'last_batch_id';

  Future<void> saveBatches(List<Batch> batches) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(batches.map((b) => b.toMap()).toList());
    await prefs.setString(_keyBatches, json);
  }

  Future<List<Batch>> loadBatches() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyBatches);
    if (json == null) return [];
    final List<dynamic> decoded = jsonDecode(json);
    return decoded.map((m) => Batch.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<void> saveLastBatchId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBatchId, id);
  }

  Future<String?> loadLastBatchId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastBatchId);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBatches);
    await prefs.remove(_keyLastBatchId);
  }
}
