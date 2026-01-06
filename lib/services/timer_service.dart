import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:workmanager/workmanager.dart';
import 'announcement_service.dart';
import 'settings_service.dart';

/// Service for managing timer logic and scheduling announcements
class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  final SettingsService _settings = SettingsService();
  final AnnouncementService _announcement = AnnouncementService();
  Timer? _foregroundTimer;
  bool _isRunning = false;

  static const String _taskName = 'timeAnnouncementTask';

  /// Initialize WorkManager for background tasks (only on Android/iOS)
  Future<void> initialize() async {
    // WorkManager only supports Android and iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Workmanager().initialize(
          callbackDispatcher,
          isInDebugMode: false,
        );
      } catch (e) {
        // If WorkManager fails to initialize, continue without it
        // The foreground timer will still work
        debugPrint('WorkManager initialization failed: $e');
      }
    }
  }

  /// Calculate the next announcement time based on the current time and interval
  /// Rounds to the next interval mark (e.g., 13:47 with 15-min interval -> 14:00)
  DateTime calculateNextAnnouncementTime(int intervalMinutes) {
    final now = DateTime.now();
    final currentMinute = now.minute;
    final currentSecond = now.second;

    // Calculate how many minutes into the current hour we are
    final minutesIntoHour = currentMinute;

    // Find the next interval mark
    int nextIntervalMark;
    if (intervalMinutes == 60) {
      // For 60 minutes, always announce at the top of the hour
      nextIntervalMark = 60;
    } else if (intervalMinutes == 1) {
      // For 1 minute, announce every minute at :00 seconds
      // Next minute is current minute + 1, or 0 if we're at minute 59
      nextIntervalMark = (minutesIntoHour + 1) % 60;
      // If we wrapped to 0, it means next hour
      if (nextIntervalMark == 0) {
        nextIntervalMark = 60;
      }
    } else if (intervalMinutes == 5) {
      // For 5 minutes, announce at :00, :05, :10, :15, :20, :25, :30, :35, :40, :45, :50, :55
      final intervals = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
      // If we're exactly at a mark and seconds > 0, go to next mark
      if (intervals.contains(minutesIntoHour) && currentSecond > 0) {
        nextIntervalMark = intervals.firstWhere(
          (mark) => mark > minutesIntoHour,
          orElse: () => 60,
        );
      } else {
        // Find next mark that's greater than current minute
        nextIntervalMark = intervals.firstWhere(
          (mark) => mark > minutesIntoHour,
          orElse: () => 60,
        );
      }
    } else if (intervalMinutes == 30) {
      // For 30 minutes, use 0 and 30
      nextIntervalMark = minutesIntoHour < 30 ? 30 : 60;
    } else {
      // For 15 minutes, find next mark from [0, 15, 30, 45]
      final intervals = [0, 15, 30, 45];
      nextIntervalMark = intervals.firstWhere(
        (mark) => mark > minutesIntoHour,
        orElse: () => 60,
      );
    }

    // Calculate the next announcement time
    DateTime nextTime;
    if (nextIntervalMark == 60) {
      // Next hour
      nextTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour + 1,
        0,
        0,
        0,
      );
    } else {
      // Same hour, different minute
      nextTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        nextIntervalMark,
        0,
        0,
      );
    }

    // If the calculated time is in the past (shouldn't happen, but safety check),
    // schedule for the next interval
    if (nextTime.isBefore(now)) {
      nextTime = nextTime.add(Duration(minutes: intervalMinutes));
    }

    return nextTime;
  }

  /// Start the timer service
  Future<void> start() async {
    if (_isRunning) return;

    await _announcement.initialize();
    final interval = await _settings.getInterval();
    await _settings.setActive(true);
    _isRunning = true;

    // Schedule background task
    await scheduleNextAnnouncement(interval);

    // Also run a foreground timer for immediate updates
    _startForegroundTimer(interval);
  }

  /// Stop the timer service
  Future<void> stop() async {
    if (!_isRunning) return;

    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    await _settings.setActive(false);
    
    // Cancel WorkManager task if available
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Workmanager().cancelByUniqueName(_taskName);
      } catch (e) {
        debugPrint('Failed to cancel WorkManager task: $e');
      }
    }
    
    _isRunning = false;
  }

  /// Check if the timer is currently running
  bool get isRunning => _isRunning;

  /// Get the next announcement time
  Future<DateTime?> getNextAnnouncementTime() async {
    if (!_isRunning) return null;
    final interval = await _settings.getInterval();
    return calculateNextAnnouncementTime(interval);
  }

  void _startForegroundTimer(int intervalMinutes) {
    _foregroundTimer?.cancel();
    
    // Calculate delay until next announcement
    final nextTime = calculateNextAnnouncementTime(intervalMinutes);
    final now = DateTime.now();
    final delay = nextTime.difference(now);

    _foregroundTimer = Timer(delay, () async {
      if (_isRunning) {
        await _announcement.announceTime();
        // Schedule next one
        await scheduleNextAnnouncement(intervalMinutes);
        _startForegroundTimer(intervalMinutes);
      }
    });
  }

  Future<void> scheduleNextAnnouncement(int intervalMinutes) async {
    // Only schedule background task on Android/iOS
    // On other platforms, the foreground timer handles announcements
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final nextTime = calculateNextAnnouncementTime(intervalMinutes);
        final now = DateTime.now();
        final delay = nextTime.difference(now);

        if (delay.inSeconds > 0) {
          await Workmanager().registerOneOffTask(
            _taskName,
            _taskName,
            initialDelay: delay,
            constraints: Constraints(
              networkType: NetworkType.not_required,
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to schedule WorkManager task: $e');
      }
    }
  }
}

/// Background task callback for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final timerService = TimerService();
    final announcementService = AnnouncementService();
    
    await announcementService.initialize();
    await announcementService.announceTime();
    
    // Reschedule next announcement
    final settings = SettingsService();
    final interval = await settings.getInterval();
    final isActive = await settings.isActive();
    
    if (isActive) {
      await timerService.scheduleNextAnnouncement(interval);
    }
    
    return true;
  });
}

