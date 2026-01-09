import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String _notificationsKey = 'notifications_enabled';
  static const String _languageKey = 'app_language';

  bool _notificationsEnabled = true;
  String _language = 'en'; // 'en', 'hi', 'bn'

  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    _language = prefs.getString(_languageKey) ?? 'en';
    notifyListeners();
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  Future<void> setLanguage(String languageCode) async {
    _language = languageCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  String getLanguageName() {
    switch (_language) {
      case 'hi':
        return 'Hindi';
      case 'bn':
        return 'Bengali';
      default:
        return 'English';
    }
  }
}
