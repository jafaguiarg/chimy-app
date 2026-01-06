import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings persistence
class SettingsService {
  static const String _intervalKey = 'announcement_interval';
  static const int _defaultInterval = 15; // Default to 15 minutes

  /// Get the saved announcement interval in minutes
  /// Returns one of: 1, 5, 15, 30, or 60
  Future<int> getInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_intervalKey) ?? _defaultInterval;
  }

  /// Save the announcement interval in minutes
  /// Valid values: 1, 5, 15, 30, or 60
  Future<void> setInterval(int minutes) async {
    if (![1, 5, 15, 30, 60].contains(minutes)) {
      throw ArgumentError('Interval must be 1, 5, 15, 30, or 60 minutes');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_intervalKey, minutes);
  }

  /// Get whether the timer is active
  Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('timer_active') ?? false;
  }

  /// Set whether the timer is active
  Future<void> setActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timer_active', active);
  }
}

