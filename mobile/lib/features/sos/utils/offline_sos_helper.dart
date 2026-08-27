import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/secure_storage.dart';

class OfflineSosHelper {
  static Future<Position?> getBestAvailableLocation() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return await Geolocator.getLastKnownPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return await Geolocator.getLastKnownPosition();
        }
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 3),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  static String buildSmsBody({
    String? category,
    double? latitude,
    double? longitude,
  }) {
    String locationText = 'Location unavailable (GPS timeout)';
    if (latitude != null && longitude != null) {
      locationText = 'https://maps.google.com/?q=$latitude,$longitude';
    }

    final alertCategory = category ?? 'High Priority Alert';

    return 'EMERGENCY ALERT!\n'
        'I triggered an urgent SOS ($alertCategory).\n'
        'My current location:\n$locationText\n\n'
        'Sent automatically via Nearo Offline Emergency.';
  }

  /// Triggers direct targeted offline emergency SMS with GPS coordinates.
  /// Aborts immediately if no recipient phone number is configured to prevent
  /// invoking the native contact list picker unexpectedly.
  static Future<bool> triggerOfflineSms({
    String? category,
    double? latitude,
    double? longitude,
    String? overridePhone,
    String? customBody,
  }) async {
    String cleanPhone = (overridePhone ?? '').trim();
    if (cleanPhone.isEmpty) {
      final savedPhone = await SecureStorageService.getEmergencyContactPhone();
      if (savedPhone != null && savedPhone.trim().isNotEmpty) {
        cleanPhone = savedPhone.trim();
      }
    }

    // Strict recipient precondition: prevent untargeted SMS dispatch / contact picker popup
    if (cleanPhone.isEmpty) {
      debugPrint('SMS Dispatch Aborted: No valid emergency recipient phone number configured.');
      return false;
    }

    double? lat = latitude;
    double? lng = longitude;

    // Fetch high accuracy current GPS coordinates if not passed
    if (lat == null || lng == null) {
      final position = await getBestAvailableLocation();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
    }

    // Format SMS message body with Google Maps link or custom text
    final messageBody = customBody ??
        buildSmsBody(
          category: category,
          latitude: lat,
          longitude: lng,
        );

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: <String, String>{
        'body': messageBody,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for devices requiring encoded string syntax
        final fallbackStr = 'sms:$cleanPhone?body=${Uri.encodeComponent(messageBody)}';
        final fallbackUri = Uri.parse(fallbackStr);
        if (await canLaunchUrl(fallbackUri)) {
          return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Failed to dispatch emergency SMS: $e');
    }
    return false;
  }

  /// Secure targeted emergency SMS dispatch with context-aware fallback navigation
  static Future<bool> sendEmergencySMS({
    required BuildContext context,
    String? category,
    String? message,
    double? latitude,
    double? longitude,
    String? overridePhone,
  }) async {
    String cleanPhone = (overridePhone ?? '').trim();
    if (cleanPhone.isEmpty) {
      final savedPhone = await SecureStorageService.getEmergencyContactPhone();
      if (savedPhone != null && savedPhone.trim().isNotEmpty) {
        cleanPhone = savedPhone.trim();
      }
    }

    if (cleanPhone.isEmpty) {
      debugPrint('SMS Service Error: Emergency contact phone number is missing.');
      if (context.mounted) {
        Navigator.of(context).pushNamed('/emergency-number-setup');
      }
      return false;
    }

    return await triggerOfflineSms(
      category: category,
      latitude: latitude,
      longitude: longitude,
      overridePhone: cleanPhone,
      customBody: message,
    );
  }

  /// Legacy alias
  static Future<bool> triggerDirectOfflineSms({
    String? category,
    double? latitude,
    double? longitude,
    String? overridePhone,
    String? overrideName,
  }) async {
    return await triggerOfflineSms(
      category: category,
      latitude: latitude,
      longitude: longitude,
      overridePhone: overridePhone,
    );
  }

  static Future<bool> dialEmergencyServices({String phoneNumber = '112'}) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        return await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
