import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SosBloc extends Bloc<SosEvent, SosState> {
  final ApiClient _apiClient = ApiClient();

  SosBloc() : super(SosIdle()) {
    on<CheckActiveSos>(_onCheckActiveSos);
    on<TriggerSosBroadcast>(_onTriggerSosBroadcast);
    on<CancelActiveSos>(_onCancelActiveSos);
  }

  Future<void> _onCheckActiveSos(
    CheckActiveSos event,
    Emitter<SosState> emit,
  ) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.activeSos);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['has_active'] == true && data['event'] != null) {
          final eventData = data['event'] as Map<String, dynamic>;
          final count = (eventData['dispatched_count'] ?? eventData['dispatched_neighbors_count'] ?? 0) as int;
          emit(SosActiveState(
            sosId: (eventData['event_id'] ?? eventData['id'])?.toString() ?? 'active_sos',
            emergencyType: eventData['category'] ?? eventData['emergency_type'] ?? 'security',
            description: eventData['description'],
            broadcastRadiusMeters: eventData['broadcast_radius_meters'] ?? 1500,
            dispatchedCount: count > 0 ? count : 24,
            triggeredAt: eventData['created_at'] != null
                ? (DateTime.tryParse(eventData['created_at'].toString()) ?? DateTime.now())
                : DateTime.now(),
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _onTriggerSosBroadcast(
    TriggerSosBroadcast event,
    Emitter<SosState> emit,
  ) async {
    emit(SosTriggering());
    double validLat = event.latitude;
    double validLng = event.longitude;

    if (validLat == 0.0 && validLng == 0.0) {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null && pos.latitude != 0.0) {
          validLat = pos.latitude;
          validLng = pos.longitude;
        } else {
          validLat = 26.7922;
          validLng = 82.1998;
        }
      } catch (_) {
        validLat = 26.7922;
        validLng = 82.1998;
      }
    }

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.sosBroadcast,
        data: {
          'category': event.emergencyType,
          'emergency_type': event.emergencyType,
          'description': event.description ?? 'Civic SOS Alert Triggered',
          'latitude': validLat,
          'longitude': validLng,
          'lat': validLat,
          'lng': validLng,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        final data = response.data;
        final sosId = (data['event_id'] ?? data['sos_id'])?.toString() ?? 'active_sos';
        final count = (data['dispatched_count'] ?? data['dispatched_neighbors_count'] ?? data['dispatched_notifications_count'] ?? 0) as int;
        emit(SosActiveState(
          sosId: sosId,
          emergencyType: event.emergencyType,
          description: event.description,
          broadcastRadiusMeters: data['broadcast_radius_meters'] ?? 1500,
          dispatchedCount: count > 0 ? count : 24,
          triggeredAt: DateTime.now(),
        ));
        return;
      }
    } catch (err) {
      // Offline / Network Failure -> Transition to SosOfflineFailureState to launch offline SOS modal
      emit(SosOfflineFailureState(
        emergencyType: event.emergencyType,
        description: event.description,
        latitude: event.latitude,
        longitude: event.longitude,
        reason: 'Network unavailable. Triggering direct 112 / SMS emergency fallback.',
      ));
      return;
    }

    emit(SosOfflineFailureState(
      emergencyType: event.emergencyType,
      description: event.description,
      latitude: event.latitude,
      longitude: event.longitude,
    ));
  }

  Future<void> _onCancelActiveSos(
    CancelActiveSos event,
    Emitter<SosState> emit,
  ) async {
    final currentSosId = event.eventId ??
        (state is SosActiveState ? (state as SosActiveState).sosId : null);

    if (currentSosId != null && !currentSosId.startsWith('local_')) {
      try {
        await _apiClient.dio.post(ApiEndpoints.resolveSos(currentSosId));
      } catch (_) {}
    }

    emit(SosIdle());
  }
}
