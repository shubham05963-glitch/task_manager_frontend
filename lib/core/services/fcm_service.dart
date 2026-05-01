import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await _messaging.getToken();
    debugPrint("FCM token: $token");

    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint("FCM token refreshed: $newToken");
      // TODO: send token to backend if you want user-targeted push notifications.
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final n = message.notification;
      if (n != null) {
        await NotificationService().showInstantNotification(
          n.title ?? "Task Alert",
          n.body ?? "You have a new update.",
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM notification tapped: ${message.messageId}");
    });
  }
}
