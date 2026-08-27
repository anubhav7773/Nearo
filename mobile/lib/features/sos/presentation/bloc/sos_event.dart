abstract class SosEvent {}

class CheckActiveSos extends SosEvent {}

class TriggerSosRequested extends SosEvent {
  final String category;
  final String? description;
  final double? latitude;
  final double? longitude;

  TriggerSosRequested({
    required this.category,
    this.description,
    this.latitude,
    this.longitude,
  });
}

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

class FetchActiveSosDetails extends SosEvent {
  final String? sosId;

  FetchActiveSosDetails({this.sosId});
}

class CancelActiveSos extends SosEvent {
  final String? eventId;

  CancelActiveSos({this.eventId});
}

class ResetSosState extends SosEvent {}
