import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/distribution_obj.dart';

class StorageHelper {
  static Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  static Future<String?> getDistObjectCurrentVersionId(
      String clientKey, String objKey) async {
    final prefs = await _getPrefs();
    final storageKey = "__configbee::$clientKey::CurrentVersionId::$objKey";
    return prefs.getString(storageKey);
  }

  static Future<void> setDistObjectCurrentVersionId(
      String clientKey, String objKey, String versionId) async {
    final prefs = await _getPrefs();
    final storageKey = "__configbee::$clientKey::CurrentVersionId::$objKey";
    await prefs.setString(storageKey, versionId);
  }

  static Future<SessionData?> getActiveSessionData(
      String clientKey, String objKey) async {
    final prefs = await _getPrefs();
    final storageKey = "__configbee::$clientKey::ActiveSession::$objKey";
    final storedString = prefs.getString(storageKey);
    if (storedString == null) {
      return null;
    }
    try {
      final json = jsonDecode(storedString) as Map<String, dynamic>;
      return SessionData.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setActiveSessionData(
      String clientKey, String objKey, SessionData sessionData) async {
    final prefs = await _getPrefs();
    final storageKey = "__configbee::$clientKey::ActiveSession::$objKey";
    await prefs.setString(storageKey, jsonEncode(sessionData.toJson()));
  }

  static Future<void> clearActiveSessionData(
      String clientKey, String objKey) async {
    final prefs = await _getPrefs();
    final storageKey = "__configbee::$clientKey::ActiveSession::$objKey";
    await prefs.remove(storageKey);
  }

  static String _generateVisitorId() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final randomPart =
        List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
    final tsPart =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '$tsPart-$randomPart';
  }

  static Future<String> getOrCreateVisitorId(
      String clientKey, String objKey) async {
    final prefs = await _getPrefs();
    final storageKey = "__configbee::$clientKey::VisitorId::$objKey";
    final existing = prefs.getString(storageKey);
    if (existing != null) return existing;
    final newId = _generateVisitorId();
    await prefs.setString(storageKey, newId);
    return newId;
  }
}
