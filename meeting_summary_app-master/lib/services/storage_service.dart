import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _projectsKey = 'projects_data';

  // ─── Save all projects ─────────────────────────────────
  static Future<void> saveProjects(List<Map<String, dynamic>> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(projects);
    await prefs.setString(_projectsKey, encoded);
  }

  // ─── Load all projects ─────────────────────────────────
  static Future<List<Map<String, dynamic>>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_projectsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ─── Clear all data ────────────────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_projectsKey);
  }
}