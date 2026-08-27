class SosEventModel {
  final String id;
  final String category;
  final String status;
  final double latitude;
  final double longitude;
  final String? description;
  final int broadcastRadiusMeters;
  final int dispatchedCount;
  final int respondersCount;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  SosEventModel({
    required this.id,
    required this.category,
    this.status = 'active',
    required this.latitude,
    required this.longitude,
    this.description,
    this.broadcastRadiusMeters = 1500,
    this.dispatchedCount = 0,
    this.respondersCount = 0,
    required this.createdAt,
    this.resolvedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isResolved => status.toLowerCase() == 'resolved';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'medical':
        return 'Medical Emergency';
      case 'fire':
        return 'Fire / Electrical Hazard';
      case 'harassment':
        return 'Security / Harassment';
      case 'security':
      case 'scam':
      default:
        return 'Suspicious Activity / Security';
    }
  }

  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E';

  factory SosEventModel.fromJson(
    Map<String, dynamic> json, {
    double? fallbackLat,
    double? fallbackLng,
  }) {
    // Parse coordinates from latitude/longitude or lat/lng or GeoJSON geometry/location
    double lat = (json['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble() ??
        fallbackLat ??
        26.7922;
    double lng = (json['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble() ??
        fallbackLng ??
        82.1998;

    if (json['location'] is Map) {
      final locMap = json['location'] as Map<String, dynamic>;
      if (locMap['coordinates'] is List && (locMap['coordinates'] as List).length >= 2) {
        lng = ((locMap['coordinates'] as List)[0] as num?)?.toDouble() ?? lng;
        lat = ((locMap['coordinates'] as List)[1] as num?)?.toDouble() ?? lat;
      }
    }

    final id = (json['event_id'] ?? json['sos_id'] ?? json['id'])?.toString() ?? '';
    final category = (json['category'] ?? json['emergency_type'] ?? 'security').toString();
    final status = (json['status'] ?? 'active').toString();
    final description = json['description'] as String?;
    final radius = (json['broadcast_radius_meters'] as num?)?.toInt() ?? 1500;

    final count = (json['dispatched_count'] ??
            json['dispatched_neighbors_count'] ??
            json['dispatched_notifications_count'] ??
            0) as num;
    final responders = (json['responders_count'] as num?)?.toInt() ?? 0;

    DateTime createdAt = DateTime.now();
    if (json['created_at'] != null) {
      createdAt = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }

    DateTime? resolvedAt;
    if (json['resolved_at'] != null) {
      resolvedAt = DateTime.tryParse(json['resolved_at'].toString());
    }

    return SosEventModel(
      id: id,
      category: category,
      status: status,
      latitude: lat,
      longitude: lng,
      description: description,
      broadcastRadiusMeters: radius,
      dispatchedCount: count.toInt(),
      respondersCount: responders,
      createdAt: createdAt,
      resolvedAt: resolvedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'broadcast_radius_meters': broadcastRadiusMeters,
      'dispatched_count': dispatchedCount,
      'responders_count': respondersCount,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  SosEventModel copyWith({
    String? id,
    String? category,
    String? status,
    double? latitude,
    double? longitude,
    String? description,
    int? broadcastRadiusMeters,
    int? dispatchedCount,
    int? respondersCount,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return SosEventModel(
      id: id ?? this.id,
      category: category ?? this.category,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      broadcastRadiusMeters: broadcastRadiusMeters ?? this.broadcastRadiusMeters,
      dispatchedCount: dispatchedCount ?? this.dispatchedCount,
      respondersCount: respondersCount ?? this.respondersCount,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
