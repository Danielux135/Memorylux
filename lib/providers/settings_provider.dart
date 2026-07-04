import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class SettingsProvider extends ChangeNotifier {
  final AuthService _authService;
  final SyncService _syncService;

  UserSettings _settings = UserSettings(userId: '');
  bool _isLoading = false;

  UserSettings get settings => _settings;
  bool get isLoading => _isLoading;

  SettingsProvider({
    required AuthService authService,
    required SyncService syncService,
  })  : _authService = authService,
        _syncService = syncService;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings');
    if (data != null) {
      _settings = UserSettings.fromMap({
        ...jsonDecode(data) as Map<String, dynamic>,
        'userId': _authService.userId,
      });
    } else {
      _settings = UserSettings(userId: _authService.userId);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_settings.toMap());
    await prefs.setString('settings', data);
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> toggleNotifications(bool enabled) async {
    _settings.notificationsEnabled = enabled;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> toggleQuietMode(bool enabled) async {
    _settings.quietModeEnabled = enabled;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> setQuietModeHours(DateTime start, DateTime end) async {
    _settings.quietModeStart = start;
    _settings.quietModeEnd = end;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> setDefaultNotificationMinutes(int minutes) async {
    _settings.defaultNotificationMinutes = minutes;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> setPersistentRepeatMinutes(int minutes) async {
    _settings.persistentRepeatMinutes = minutes;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> toggleDailySummary(bool enabled) async {
    _settings.dailySummaryEnabled = enabled;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> setDailySummaryTime(int hour, int minute) async {
    _settings.dailySummaryHour = hour;
    _settings.dailySummaryMinute = minute;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> setLanguage(String lang) async {
    _settings.language = lang;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> setThemeMode(String mode) async {
    _settings.themeMode = mode;
    _saveToLocal();
    notifyListeners();
    await _syncService.pushSettings(
      userId: _authService.userId,
      settings: _settings,
    );
  }

  Future<void> toggleSync(bool enabled) async {
    _settings.syncEnabled = enabled;
    _saveToLocal();
    notifyListeners();
  }

  Future<void> syncWithCloud() async {
    await _syncService.syncSettings(
      userId: _authService.userId,
      localSettings: _settings,
      onUpdate: (cloudSettings) {
        _settings = cloudSettings;
        _saveToLocal();
        notifyListeners();
      },
    );
  }
}
