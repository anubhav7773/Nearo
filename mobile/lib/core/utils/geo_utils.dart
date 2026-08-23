import 'dart:math';

class GeoUtils {
  /// Calculate geographic distance between two coordinates in kilometers using the Haversine formula.
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

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }
}
