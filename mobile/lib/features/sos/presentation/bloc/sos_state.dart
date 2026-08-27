import '../../data/models/sos_event_model.dart';

abstract class SosState {}

class SosIdle extends SosState {}

class SosDispatchingState extends SosState {}

// Backwards compatibility alias
class SosTriggering extends SosDispatchingState {}

class SosDispatchedSuccess extends SosState {
  final SosEventModel sosEvent;

  SosDispatchedSuccess({required this.sosEvent});

  String get sosId => sosEvent.id;
  String get emergencyType => sosEvent.category;
  String? get description => sosEvent.description;
  int get broadcastRadiusMeters => sosEvent.broadcastRadiusMeters;
  int get dispatchedCount => sosEvent.dispatchedCount;
  DateTime get triggeredAt => sosEvent.createdAt;
}

// Backwards compatibility subclass
class SosActiveState extends SosDispatchedSuccess {
  SosActiveState({
    required super.sosEvent,
  });

  factory SosActiveState.legacy({
    required String sosId,
    required String emergencyType,
    String? description,
    int broadcastRadiusMeters = 1500,
    int dispatchedCount = 0,
    required DateTime triggeredAt,
    double latitude = 26.7922,
    double longitude = 82.1998,
  }) {
    return SosActiveState(
      sosEvent: SosEventModel(
        id: sosId,
        category: emergencyType,
        status: 'active',
        latitude: latitude,
        longitude: longitude,
        description: description,
        broadcastRadiusMeters: broadcastRadiusMeters,
        dispatchedCount: dispatchedCount,
        createdAt: triggeredAt,
      ),
    );
  }
}

class SosDispatchFailure extends SosState {
  final String errorMessage;
  final String category;
  final String? description;
  final double latitude;
  final double longitude;

  SosDispatchFailure({
    required this.errorMessage,
    this.category = 'security',
    this.description,
    this.latitude = 26.7922,
    this.longitude = 82.1998,
  });
}

class SosOfflineFailureState extends SosDispatchFailure {
  final String reason;

  SosOfflineFailureState({
    required String emergencyType,
    super.description,
    required super.latitude,
    required super.longitude,
    this.reason = 'Network connection unavailable. Offline emergency fallback activated.',
  }) : super(
          errorMessage: reason,
          category: emergencyType,
        );

  String get emergencyType => category;
}

class SosErrorState extends SosState {
  final String message;

  SosErrorState(this.message);
}

class SosCancelledSuccess extends SosState {}
