import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../domain/sos_repository.dart';
import 'models/sos_event_model.dart';

class SosRepositoryImpl implements SosRepository {
  final ApiClient _apiClient;

  SosRepositoryImpl({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<SosEventModel> triggerSos({
    required String category,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    final response = await _apiClient.dio.post(
      ApiEndpoints.sosBroadcast,
      data: {
        'category': category,
        'emergency_type': category,
        'latitude': latitude,
        'longitude': longitude,
        'lat': latitude,
        'lng': longitude,
        'description': description ?? 'Civic SOS Emergency Broadcast',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      return SosEventModel.fromJson(
        data,
        fallbackLat: latitude,
        fallbackLng: longitude,
      );
    }
    throw Exception('Failed to broadcast SOS alert (status: ${response.statusCode})');
  }

  @override
  Future<SosEventModel?> fetchActiveSos() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.activeSos);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['has_active'] == true && data['event'] != null) {
          final eventData = data['event'] as Map<String, dynamic>;
          return SosEventModel.fromJson(eventData);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SosEventModel?> fetchActiveSosDetails(String sosId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.activeSos);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['has_active'] == true && data['event'] != null) {
          final eventData = data['event'] as Map<String, dynamic>;
          final model = SosEventModel.fromJson(eventData);
          if (model.id == sosId || sosId.isEmpty) {
            return model;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancelSos(String sosId) async {
    if (sosId.isEmpty) return;
    await _apiClient.dio.post(ApiEndpoints.resolveSos(sosId));
  }
}
