import 'package:flutter_test/flutter_test.dart';
import 'package:emergency_user/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Notification Service Tests', () {
    test('NotificationService initializes and fires notifications into history safely', () async {
      await NotificationService.initialize();

      final initialCount = NotificationService.notifications.length;

      await NotificationService.showEmergencyNotification(
        id: 7771,
        title: '🚑 Ambulance Assigned!',
        body: 'Ambulance KA-01-EQ-9921 is en route. ETA: 4 mins.',
      );

      expect(NotificationService.notifications.length, initialCount + 1);
      expect(NotificationService.notifications.first.title, '🚑 Ambulance Assigned!');
      expect(NotificationService.notifications.first.body, contains('KA-01-EQ-9921'));

      await NotificationService.showDriverChatNotification(
        id: 7772,
        title: '💬 Message from Pilot',
        body: 'I have arrived near your building main gate.',
      );

      expect(NotificationService.notifications.length, initialCount + 2);
      expect(NotificationService.notifications.first.type, 'chat');

      await NotificationService.cancel(7771);
      await NotificationService.cancelAll();
    });
  });
}
