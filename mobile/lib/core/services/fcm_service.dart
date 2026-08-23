import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';

class FCMNotificationService {
  static final FCMNotificationService _instance =
      FCMNotificationService._internal();
  factory FCMNotificationService() => _instance;
  FCMNotificationService._internal();

  final ApiClient _apiClient = ApiClient();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request notification permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('FCM Permission Status: ${settings.authorizationStatus}');
      }

      // 2. Fetch and register device FCM token
      final token = await messaging.getToken();
      if (token != null) {
        await syncTokenToBackend(token);
      }

      // 3. Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        syncTokenToBackend(newToken);
      });

      // 4. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Received foreground notification: ${message.notification?.title}');
        }
      });

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('FCM Initialization deferred/skipped: $e');
      }
    }
  }

  Future<void> syncTokenToBackend(String token) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.userFcmToken,
        data: {'fcm_token': token},
      );
    } catch (_) {}
  }
}
