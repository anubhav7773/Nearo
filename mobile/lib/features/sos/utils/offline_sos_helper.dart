import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

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

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      ).catchError((_) async => await Geolocator.getLastKnownPosition());
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  static String buildSmsBody({
    String? category,
    double? latitude,
    double? longitude,
  }) {
    String locationText = 'Location unavailable';
    if (latitude != null && longitude != null) {
      locationText = 'https://maps.google.com/?q=$latitude,$longitude';
    }

    final alertCategory = category ?? 'General Emergency';
    return 'EMERGENCY ALERT!\n'
        'Type: $alertCategory\n'
        'I need immediate assistance at my location:\n$locationText\n\n'
        '(Sent via Nearo Offline Emergency)';
  }

  static Future<bool> triggerOfflineSms({
    String? category,
    double? latitude,
    double? longitude,
    String? phoneNumber,
  }) async {
    double? lat = latitude;
    double? lng = longitude;

    if (lat == null || lng == null) {
      final position = await getBestAvailableLocation();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
    }

    final messageBody = buildSmsBody(
      category: category,
      latitude: lat,
      longitude: lng,
    );

    final targetNumber = phoneNumber ?? '';
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: targetNumber,
      queryParameters: <String, String>{
        'body': messageBody,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for devices that require encoded URL string
        final fallbackUri = Uri.parse(
          'sms:$targetNumber?body=${Uri.encodeComponent(messageBody)}',
        );
        if (await canLaunchUrl(fallbackUri)) {
          return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {}
    return false;
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
