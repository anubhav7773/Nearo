import 'dart:math';

class GeoUtils {
  /// Calculate geographic distance between two coordinates in kilometers using Haversine formula.
  static double distanceBetweenInKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degreesToRadians(endLat - startLat);
    final double dLon = _degreesToRadians(endLng - startLng);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLat)) *
            cos(_degreesToRadians(endLat)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Calculate geographic distance in meters.
  static double distanceBetweenInMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return distanceBetweenInKm(startLat, startLng, endLat, endLng) * 1000.0;
  }

  /// Apply client-side 200m–500m coordinate jitter for DPDP zero-knowledge privacy compliance
  static Map<String, double> applyJitter({
    required double latitude,
    required double longitude,
    double minMeters = 200.0,
    double maxMeters = 500.0,
  }) {
    final random = Random();
    final double distance =
        minMeters + random.nextDouble() * (maxMeters - minMeters);
    final double angle = random.nextDouble() * 2 * pi;

    const double metersPerDegreeLat = 111320.0;
    final double deltaLat = (distance * cos(angle)) / metersPerDegreeLat;
    final double metersPerDegreeLon =
        111320.0 * cos(latitude * pi / 180.0);
    final double deltaLon = (distance * sin(angle)) / metersPerDegreeLon;

    return {
      'latitude': latitude + deltaLat,
      'longitude': longitude + deltaLon,
    };
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }
}
