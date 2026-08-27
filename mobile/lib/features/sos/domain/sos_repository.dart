import '../data/models/sos_event_model.dart';

abstract class SosRepository {
  Future<SosEventModel> triggerSos({
    required String category,
    required double latitude,
    required double longitude,
    String? description,
  });

  Future<SosEventModel?> fetchActiveSos();

  Future<SosEventModel?> fetchActiveSosDetails(String sosId);

  Future<void> cancelSos(String sosId);
}
