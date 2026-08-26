import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../network/secure_storage.dart';

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

      // 2. Setup token refresh listener (syncs if authenticated)
      messaging.onTokenRefresh.listen((newToken) {
        syncTokenToBackend(newToken);
      });

      // 3. Foreground message listener
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

  /// Sends the current FCM device token to the backend only when an authentication JWT is present.
  Future<void> syncTokenToBackend([String? token]) async {
    try {
      final authToken = await SecureStorageService.getAccessToken();
      if (authToken == null || authToken.trim().isEmpty) {
        // User not logged in yet -> Gracefully abort sync until AuthBloc emits authenticated state
        if (kDebugMode) {
          print('FCM Sync deferred: No active authentication session.');
        }
        return;
      }

      final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.trim().isEmpty) return;

      await _apiClient.dio.post(
        ApiEndpoints.userFcmToken,
        data: {'fcm_token': fcmToken},
      );
      if (kDebugMode) {
        print('FCM Token registered with backend successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('FCM Token registration failed: $e');
      }
    }
  }

  /// Alias for syncTokenToBackend
  Future<void> sendFcmTokenToServer([String? token]) => syncTokenToBackend(token);
}
