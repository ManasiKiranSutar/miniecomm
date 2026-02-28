import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  late FirebaseMessaging messaging;

  NotificationService() {
    messaging = FirebaseMessaging.instance;
  }

  void requestNotificationPermission() async {
    try {
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        criticalAlert: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('Permission granted by user');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('Permission granted provisionally');
      } else {
        print('Permission denied by user');
      }
    } catch (e) {
      print('Error requesting notification permission: $e');
    }
  }

  Future<String?> getFcmToken() async {
    try {
      String? token = await messaging.getToken();
      print('FCM Token: $token');
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }
}