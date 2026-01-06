import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/time_formatter.dart';

/// Service for handling time announcements via TTS and notifications
class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  FlutterTts? _flutterTts;
  FlutterLocalNotificationsPlugin? _notifications;
  bool _isInitialized = false;

  /// Initialize TTS and notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize TTS
    _flutterTts = FlutterTts();
    await _flutterTts?.setLanguage('en-US');
    await _flutterTts?.setSpeechRate(0.5);
    await _flutterTts?.setVolume(1.0);
    await _flutterTts?.setPitch(1.0);

    // Initialize notifications
    _notifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notifications?.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    // Request permissions
    if (_notifications != null) {
      await _notifications!.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      await _notifications!.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _notifications!.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _isInitialized = true;
  }

  /// Announce the current time using TTS and show a notification
  Future<void> announceTime() async {
    if (!_isInitialized) {
      await initialize();
    }

    final now = DateTime.now();
    final timeString = TimeFormatter.toMilitaryTime(now);
    final speechText = 'THE TIME IS $timeString';
    
    // Speak the time
    await _flutterTts?.speak(speechText);

    // Show notification
    const androidDetails = AndroidNotificationDetails(
      'time_announcements',
      'Time Announcements',
      channelDescription: 'Notifications for time announcements',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notifications?.show(
      now.millisecondsSinceEpoch % 100000,
      'Time Announcement',
      timeString,
      notificationDetails,
    );
  }
}

