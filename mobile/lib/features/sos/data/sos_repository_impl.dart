import 'package:dio/dio.dart';
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
    double radiusMeters = 1500.0,
    String? description,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/sos',
        data: {
          'category': category.toLowerCase().replaceAll(' ', '_'),
          'emergency_type': category.toLowerCase().replaceAll(' ', '_'),
          'latitude': latitude,
          'longitude': longitude,
          'lat': latitude,
          'lng': longitude,
          'radius_meters': radiusMeters,
          'broadcast_radius_meters': radiusMeters,
          'description': description ?? 'Civic SOS Emergency Broadcast for $category',
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
    } on DioException catch (dioErr) {
      final serverMessage = dioErr.response?.data is Map
          ? (dioErr.response?.data['detail'] ?? dioErr.message)
          : dioErr.message;
      throw Exception('Dispatch error: $serverMessage');
    }
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
      if (sosId.isNotEmpty) {
        try {
          final response = await _apiClient.dio.get('/sos/$sosId');
          if (response.statusCode == 200 && response.data != null) {
            return SosEventModel.fromJson(response.data as Map<String, dynamic>);
          }
        } catch (_) {}
      }

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
    try {
      await _apiClient.dio.post(ApiEndpoints.resolveSos(sosId));
    } catch (_) {
      await _apiClient.dio.post('/sos/$sosId/cancel');
    }
  }
}
