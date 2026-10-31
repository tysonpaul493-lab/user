import 'package:flutter/material.dart';

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

  static List<EmergencyNotification> get notifications => List.unmodifiable(_notifications);

  /// Initialize Firebase Cloud Messaging hooks
  static Future<void> initialize() async {
    debugPrint('🔔 [FCM] Notification service initialized.');
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
}
