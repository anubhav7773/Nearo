abstract class SosState {}

class SosIdle extends SosState {}

class SosTriggering extends SosState {}

class SosActiveState extends SosState {
  final String sosId;
  final String emergencyType;
  final String? description;
  final int broadcastRadiusMeters;
  final int dispatchedCount;
  final DateTime triggeredAt;

  SosActiveState({
    required this.sosId,
    required this.emergencyType,
    this.description,
    this.broadcastRadiusMeters = 1500,
    this.dispatchedCount = 0,
    required this.triggeredAt,
  });
}

class SosOfflineFailureState extends SosState {
  final String emergencyType;
  final String? description;
  final double latitude;
  final double longitude;
  final String reason;

  SosOfflineFailureState({
    required this.emergencyType,
    this.description,
    required this.latitude,
    required this.longitude,
    this.reason = 'Network connection unavailable. Offline emergency fallback activated.',
  });
}

class SosErrorState extends SosState {
  final String message;

  SosErrorState(this.message);
}
