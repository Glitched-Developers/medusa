import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Base abstract class for all services working with storage
abstract class BaseStorageService {
  // Use regular SharedPreferences instead of SharedPreferencesWithCache
  static SharedPreferences? _prefs;

  /// Initialize storage
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get SharedPreferences instance
  Future<SharedPreferences> getPrefs() async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // METHODS FOR WORKING WITH DIFFERENT DATA TYPES
  Future<void> setInt(String key, int value) async {
    final prefs = await getPrefs();
    await prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await getPrefs();
    return prefs.getInt(key);
  }

  Future<void> setString(String key, String value) async {
    final prefs = await getPrefs();
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await getPrefs();
    return prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await getPrefs();
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await getPrefs();
    return prefs.getBool(key);
  }

  Future<void> setStringList(String key, List<String> value) async {
    final prefs = await getPrefs();
    await prefs.setStringList(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    final prefs = await getPrefs();
    return prefs.getStringList(key);
  }

  Future<void> setDouble(String key, double value) async {
    final prefs = await getPrefs();
    await prefs.setDouble(key, value);
  }

  Future<double?> getDouble(String key) async {
    final prefs = await getPrefs();
    return prefs.getDouble(key);
  }

  Future<bool> containsKey(String key) async {
    final prefs = await getPrefs();
    return prefs.containsKey(key);
  }

  Future<void> remove(String key) async {
    final prefs = await getPrefs();
    await prefs.remove(key);
  }

  // ADDITIONAL METHODS FOR WORKING WITH OBJECTS
  Future<void> saveObject(String key, Map<String, dynamic> data) async {
    await setString(key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getObject(String key) async {
    final jsonString = await getString(key);
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveObjectList(String key, List<Map<String, dynamic>> dataList) async {
    await setString(key, jsonEncode(dataList));
  }

  Future<List<Map<String, dynamic>>?> getObjectList(String key) async {
    final jsonString = await getString(key);
    if (jsonString == null) return null;

    try {
      final list = jsonDecode(jsonString) as List;
      return list.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      return null;
    }
  }
}