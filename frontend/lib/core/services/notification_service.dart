import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class EmergencyNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String type;

  EmergencyNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
  });
}

class NotificationService {
  static final List<EmergencyNotification> _notifications = [];
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;
  static List<EmergencyNotification> get notifications => List.unmodifiable(_notifications);

  static const String _alertChannelId = 'emergency_alerts_channel';
  static const String _alertChannelName = 'A2I Emergency Alerts';
  static const String _alertChannelDesc = 'Real-time notifications for ambulance dispatch, arrival, and hospital transport';

  static const String _chatChannelId = 'driver_chat_channel';
  static const String _chatChannelName = 'Ambulance Driver Chat';
  static const String _chatChannelDesc = 'Urgent messages from ambulance driver and medical dispatchers';

  /// Initialize local notifications and register high-priority channels
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // On Android 13+ (API 33+), request POST_NOTIFICATIONS runtime permission
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('🔔 [UserNotificationService] System notifications initialized successfully');
    } catch (e) {
      debugPrint('ℹ️ [UserNotificationService] Local notifications platform channel inactive: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 [UserNotificationService] Notification tapped: ${response.payload}');
  }

  /// Show high-priority emergency status notification
  static Future<void> showEmergencyNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String type = 'dispatch',
  }) async {
    // Avoid repeating identical notifications within short timeframe
    if (_notifications.isNotEmpty &&
        _notifications.first.title == title &&
        _notifications.first.body == body) {
      return;
    }
    _notifications.removeWhere((n) => n.id == id.toString() && n.title == title);
    _notifications.insert(
      0,
      EmergencyNotification(
        id: id.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        type: type,
      ),
    );

    if (!_isInitialized) return;

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        channelDescription: _alertChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        ticker: '🚨 A2I Emergency Alert',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('⚠️ [UserNotificationService] showEmergencyNotification error: $e');
    }
  }

  /// Show message from ambulance driver
  static Future<void> showDriverChatNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_notifications.isNotEmpty &&
        _notifications.first.title == title &&
        _notifications.first.body == body) {
      return;
    }
    _notifications.removeWhere((n) => n.id == id.toString() && n.title == title);
    _notifications.insert(
      0,
      EmergencyNotification(
        id: id.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        type: 'chat',
      ),
    );

    if (!_isInitialized) return;

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        channelDescription: _chatChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.message,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('⚠️ [UserNotificationService] showDriverChatNotification error: $e');
    }
  }

  /// Show in-app banner alert for dispatch updates
  static void showInAppAlert(BuildContext context, {required String title, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2124),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE21B1B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    _notifications.insert(
      0,
      EmergencyNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: message,
        timestamp: DateTime.now(),
        type: 'dispatch',
      ),
    );
  }

  /// Cancel specific notification
  static Future<void> cancel(int id) async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
