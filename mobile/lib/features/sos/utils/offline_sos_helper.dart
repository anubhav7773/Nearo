import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/secure_storage.dart';

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
    String? contactName,
  }) {
    String locationText = 'Location unavailable (GPS timeout)';
    if (latitude != null && longitude != null) {
      locationText = 'https://maps.google.com/?q=$latitude,$longitude';
    }

    final recipientGreeting = (contactName != null && contactName.trim().isNotEmpty)
        ? 'Dear $contactName,\n'
        : '';
    final alertCategory = category ?? 'High Priority Alert';

    return 'EMERGENCY ALERT!\n'
        '$recipientGreeting'
        'I triggered an urgent SOS ($alertCategory).\n'
        'My current location:\n$locationText\n\n'
        'Sent automatically via Nearo Offline Emergency.';
  }

  static Future<Map<String, String?>> getSavedEmergencyContact() async {
    final phone = await SecureStorageService.getEmergencyContactPhone();
    final name = await SecureStorageService.getEmergencyContactName();
    return {
      'phone': phone,
      'name': name,
    };
  }

  static Future<bool> hasSavedEmergencyContact() async {
    return await SecureStorageService.hasEmergencyContact();
  }

  /// Triggers direct offline emergency SMS to saved guardian phone number
  static Future<bool> triggerDirectOfflineSms({
    String? category,
    double? latitude,
    double? longitude,
    String? overridePhone,
    String? overrideName,
  }) async {
    // 1. Fetch saved guardian contact or use overrides
    final savedPhone = overridePhone ?? await SecureStorageService.getEmergencyContactPhone();
    final savedName = overrideName ?? await SecureStorageService.getEmergencyContactName();

    double? lat = latitude;
    double? lng = longitude;

    // 2. Fetch high accuracy current GPS coordinates if not passed
    if (lat == null || lng == null) {
      final position = await getBestAvailableLocation();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
    }

    // 3. Format SMS message body with Google Maps link
    final messageBody = buildSmsBody(
      category: category,
      latitude: lat,
      longitude: lng,
      contactName: savedName,
    );

    // 4. Construct direct-to-number SMS URI
    final cleanPhone = (savedPhone ?? '').trim();
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: cleanPhone.isNotEmpty ? cleanPhone : null,
      queryParameters: <String, String>{
        'body': messageBody,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for devices requiring encoded string syntax
        final fallbackStr = cleanPhone.isNotEmpty
            ? 'sms:$cleanPhone?body=${Uri.encodeComponent(messageBody)}'
            : 'sms:?body=${Uri.encodeComponent(messageBody)}';
        final fallbackUri = Uri.parse(fallbackStr);
        if (await canLaunchUrl(fallbackUri)) {
          return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {}
    return false;
  }

  /// Legacy alias maintained for existing call-sites
  static Future<bool> triggerOfflineSms({
    String? category,
    double? latitude,
    double? longitude,
    String? phoneNumber,
  }) async {
    return await triggerDirectOfflineSms(
      category: category,
      latitude: latitude,
      longitude: longitude,
      overridePhone: phoneNumber,
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
