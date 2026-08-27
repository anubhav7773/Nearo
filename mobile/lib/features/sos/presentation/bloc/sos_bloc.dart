import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/sos_repository_impl.dart';
import '../../domain/sos_repository.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SosBloc extends Bloc<SosEvent, SosState> {
  final SosRepository _repository;

  SosBloc({SosRepository? repository})
      : _repository = repository ?? SosRepositoryImpl(),
        super(SosIdle()) {
    on<CheckActiveSos>(_onCheckActiveSos);
    on<TriggerSosRequested>(_onTriggerSosRequested);
    on<TriggerSosBroadcast>(_onTriggerSosBroadcast);
    on<FetchActiveSosDetails>(_onFetchActiveSosDetails);
    on<CancelActiveSos>(_onCancelActiveSos);
    on<ResetSosState>(_onResetSosState);
  }

  Future<void> _onCheckActiveSos(
    CheckActiveSos event,
    Emitter<SosState> emit,
  ) async {
    try {
      final activeEvent = await _repository.fetchActiveSos();
      if (activeEvent != null && activeEvent.isActive) {
        emit(SosActiveState(sosEvent: activeEvent));
      }
    } catch (_) {}
  }

  Future<void> _onTriggerSosRequested(
    TriggerSosRequested event,
    Emitter<SosState> emit,
  ) async {
    await _performSosDispatch(
      category: event.category,
      description: event.description,
      initialLat: event.latitude,
      initialLng: event.longitude,
      emit: emit,
    );
  }

  Future<void> _onTriggerSosBroadcast(
    TriggerSosBroadcast event,
    Emitter<SosState> emit,
  ) async {
    await _performSosDispatch(
      category: event.emergencyType,
      description: event.description,
      initialLat: event.latitude,
      initialLng: event.longitude,
      emit: emit,
    );
  }

  Future<void> _performSosDispatch({
    required String category,
    String? description,
    double? initialLat,
    double? initialLng,
    required Emitter<SosState> emit,
  }) async {
    emit(SosDispatchingState());

    double validLat = initialLat ?? 0.0;
    double validLng = initialLng ?? 0.0;

    // Perform GPS lock if coordinates are missing or default zero
    if (validLat == 0.0 && validLng == 0.0) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 4),
          );
          validLat = pos.latitude;
          validLng = pos.longitude;
        } else {
          final pos = await Geolocator.getLastKnownPosition();
          if (pos != null) {
            validLat = pos.latitude;
            validLng = pos.longitude;
          }
        }
      } catch (_) {
        try {
          final pos = await Geolocator.getLastKnownPosition();
          if (pos != null) {
            validLat = pos.latitude;
            validLng = pos.longitude;
          }
        } catch (_) {}
      }
    }

    if (validLat == 0.0 && validLng == 0.0) {
      validLat = 26.7922;
      validLng = 82.1998;
    }

    try {
      final sosEvent = await _repository.triggerSos(
        category: category,
        latitude: validLat,
        longitude: validLng,
        description: description ?? 'Civic SOS Emergency Broadcast',
      );

      emit(SosDispatchedSuccess(sosEvent: sosEvent));
    } catch (err) {
      emit(
        SosDispatchFailure(
          errorMessage: 'Unable to connect to emergency dispatch server. Check connection or use Offline Mode.',
          category: category,
          description: description,
          latitude: validLat,
          longitude: validLng,
        ),
      );
    }
  }

  Future<void> _onFetchActiveSosDetails(
    FetchActiveSosDetails event,
    Emitter<SosState> emit,
  ) async {
    try {
      final activeEvent = await _repository.fetchActiveSosDetails(event.sosId ?? '');
      if (activeEvent != null) {
        if (activeEvent.isResolved || activeEvent.isCancelled) {
          emit(SosCancelledSuccess());
          emit(SosIdle());
        } else {
          emit(SosDispatchedSuccess(sosEvent: activeEvent));
        }
      }
    } catch (_) {}
  }

  Future<void> _onCancelActiveSos(
    CancelActiveSos event,
    Emitter<SosState> emit,
  ) async {
    final currentSosId = event.eventId ??
        (state is SosDispatchedSuccess ? (state as SosDispatchedSuccess).sosId : null);

    if (currentSosId != null && currentSosId.isNotEmpty) {
      try {
        await _repository.cancelSos(currentSosId);
      } catch (_) {}
    }

    emit(SosCancelledSuccess());
    emit(SosIdle());
  }

  void _onResetSosState(
    ResetSosState event,
    Emitter<SosState> emit,
  ) {
    emit(SosIdle());
  }
}
