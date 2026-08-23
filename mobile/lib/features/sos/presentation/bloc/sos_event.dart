abstract class SosEvent {}

class CheckActiveSos extends SosEvent {}

class TriggerSosBroadcast extends SosEvent {
  final String emergencyType;
  final String? description;
  final double latitude;
  final double longitude;

  TriggerSosBroadcast({
    required this.emergencyType,
    this.description,
    required this.latitude,
    required this.longitude,
  });
}

class CancelActiveSos extends SosEvent {
  final String? eventId;

  CancelActiveSos({this.eventId});
}

class FetchActiveEmergencyRadius extends SosEvent {
  final double lat;
  final double lng;

  FetchActiveEmergencyRadius({required this.lat, required this.lng});
}
