import 'dart:convert';
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
}
