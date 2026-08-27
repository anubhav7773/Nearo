import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearo/core/theme/app_theme.dart';
import 'package:nearo/features/sos/data/models/sos_event_model.dart';
import 'package:nearo/features/sos/domain/sos_repository.dart';
import 'package:nearo/features/sos/presentation/bloc/sos_bloc.dart';
import 'package:nearo/features/sos/presentation/bloc/sos_event.dart';
import 'package:nearo/features/sos/presentation/bloc/sos_state.dart';
import 'package:nearo/features/sos/presentation/screens/active_sos_screen.dart';
import 'package:nearo/features/sos/presentation/screens/sos_screen.dart';
import 'package:nearo/features/sos/presentation/widgets/offline_sos_modal.dart';
import 'package:nearo/features/sos/utils/offline_sos_helper.dart';

class MockSosRepository implements SosRepository {
  bool shouldFail = false;
  bool cancelCalled = false;
  SosEventModel? activeEvent;

  @override
  Future<SosEventModel> triggerSos({
    required String category,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    if (shouldFail) {
      throw Exception('Network connection timed out');
    }

    final event = SosEventModel(
      id: 'test-sos-1234',
      category: category,
      status: 'active',
      latitude: latitude,
      longitude: longitude,
      description: description,
      broadcastRadiusMeters: 1500,
      dispatchedCount: 18,
      respondersCount: 2,
      createdAt: DateTime.now(),
    );
    activeEvent = event;
    return event;
  }

  @override
  Future<SosEventModel?> fetchActiveSos() async {
    return activeEvent;
  }

  @override
  Future<SosEventModel?> fetchActiveSosDetails(String sosId) async {
    return activeEvent;
  }

  @override
  Future<void> cancelSos(String sosId) async {
    cancelCalled = true;
    activeEvent = null;
  }
}

void main() {
  group('SosEventModel Tests', () {
    test('parses JSON payload from backend broadcast endpoint correctly', () {
      final json = {
        'event_id': '8e2d4211-1234-4567-89ab-cdef01234567',
        'status': 'active',
        'category': 'medical',
        'broadcast_radius_meters': 2000,
        'dispatched_count': 32,
        'responders_count': 4,
        'latitude': 26.7922,
        'longitude': 82.1998,
        'created_at': '2026-08-27T10:00:00.000Z',
      };

      final model = SosEventModel.fromJson(json);

      expect(model.id, equals('8e2d4211-1234-4567-89ab-cdef01234567'));
      expect(model.category, equals('medical'));
      expect(model.status, equals('active'));
      expect(model.isActive, isTrue);
      expect(model.isResolved, isFalse);
      expect(model.categoryDisplayName, equals('Medical Emergency'));
      expect(model.broadcastRadiusMeters, equals(2000));
      expect(model.dispatchedCount, equals(32));
      expect(model.respondersCount, equals(4));
      expect(model.latitude, equals(26.7922));
      expect(model.longitude, equals(82.1998));
      expect(model.formattedCoordinates, contains('26.7922° N'));
    });
  });

  group('OfflineSosHelper Tests', () {
    test('buildSmsBody formats category and Google Maps link correctly', () {
      final body = OfflineSosHelper.buildSmsBody(
        category: 'Medical Emergency',
        latitude: 26.7922,
        longitude: 82.1998,
      );

      expect(body, contains('EMERGENCY ALERT!'));
      expect(body, contains('SOS (Medical Emergency)'));
      expect(body, contains('https://maps.google.com/?q=26.7922,82.1998'));
      expect(body, contains('Nearo Offline Emergency'));
    });

    test('buildSmsBody handles null coordinates with fallback text', () {
      final body = OfflineSosHelper.buildSmsBody(category: 'Fire');
      expect(body, contains('SOS (Fire)'));
      expect(body, contains('Location unavailable'));
    });
  });

  group('SosBloc Unit Tests', () {
    test('TriggerSosRequested emits SosDispatchingState then SosDispatchedSuccess',
        () async {
      final mockRepo = MockSosRepository();
      final bloc = SosBloc(repository: mockRepo);

      final states = <SosState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(
        TriggerSosRequested(
          category: 'medical',
          description: 'Heart palpitations reported',
          latitude: 26.7922,
          longitude: 82.1998,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states[0], isA<SosDispatchingState>());
      expect(states[1], isA<SosDispatchedSuccess>());

      final success = states[1] as SosDispatchedSuccess;
      expect(success.sosEvent.category, equals('medical'));
      expect(success.sosEvent.dispatchedCount, equals(18));

      await subscription.cancel();
      await bloc.close();
    });

    test('TriggerSosRequested emits SosDispatchFailure when network call fails',
        () async {
      final mockRepo = MockSosRepository()..shouldFail = true;
      final bloc = SosBloc(repository: mockRepo);

      final states = <SosState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(
        TriggerSosRequested(
          category: 'fire',
          latitude: 26.7922,
          longitude: 82.1998,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states[0], isA<SosDispatchingState>());
      expect(states[1], isA<SosDispatchFailure>());

      final failure = states[1] as SosDispatchFailure;
      expect(failure.category, equals('fire'));

      await subscription.cancel();
      await bloc.close();
    });

    test('CancelActiveSos resolves the SOS and resets to idle', () async {
      final mockRepo = MockSosRepository();
      final bloc = SosBloc(repository: mockRepo);

      bloc.add(CancelActiveSos(eventId: 'test-sos-1234'));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockRepo.cancelCalled, isTrue);
      expect(bloc.state, isA<SosIdle>());

      await bloc.close();
    });
  });

  group('Civic SOS Screen, ActiveSosScreen & OfflineSosModal Widget Tests', () {
    testWidgets('SosScreen renders SOS Hold button, categories, and offline banner',
        (WidgetTester tester) async {
      final mockRepo = MockSosRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<SosBloc>(
            create: (_) => SosBloc(repository: mockRepo),
            child: const SosScreen(),
          ),
        ),
      );

      // Pump past the 4-second geolocation timeout timer
      await tester.pump(const Duration(seconds: 5));

      // Verify Header
      expect(find.text('Civic SOS Dispatch'), findsOneWidget);
      expect(find.text('CIVIC SOS EMERGENCY BROADCAST'), findsOneWidget);

      // Verify Hold 1.5s Button
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('HOLD 1.5s'), findsOneWidget);

      // Verify Emergency Category Options
      expect(find.text('Suspicious Activity / Scam'), findsOneWidget);
      expect(find.text('Medical Emergency'), findsOneWidget);
      expect(find.text('Fire / Electrical Hazard'), findsOneWidget);
      expect(find.text('Security / Harassment'), findsOneWidget);

      // Verify Offline Emergency Banner
      final bannerFinder = find.text('Offline Emergency Mode: 1-Tap 112 Dial & Direct SMS');
      expect(bannerFinder, findsOneWidget);

      // Scroll to banner and tap to open Offline Emergency bottom sheet
      await tester.ensureVisible(bannerFinder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(bannerFinder);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Offline Emergency Dispatch'), findsOneWidget);
      expect(find.text('Send Emergency SMS with GPS Link'), findsOneWidget);
      expect(find.text('Call 112 Emergency Services'), findsOneWidget);
    });

    testWidgets('OfflineSosModal renders GPS Lock and 1-tap dial hotlines',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfflineSosModal(
                latitude: 26.7922,
                longitude: 82.1998,
                emergencyType: 'medical',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Offline Emergency Dispatch'), findsOneWidget);
      expect(find.text('GPS Lock: 26.7922° N, 82.1998° E'), findsOneWidget);
      expect(find.text('Send Emergency SMS with GPS Link'), findsOneWidget);
      expect(find.text('Call 112 Emergency Services'), findsOneWidget);
      expect(find.text('112'), findsOneWidget);
      expect(find.text('108'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('ActiveSosScreen renders live broadcast metrics and cancel action',
        (WidgetTester tester) async {
      final mockRepo = MockSosRepository();
      final testEvent = SosEventModel(
        id: 'test-event-uuid-1',
        category: 'medical',
        status: 'active',
        latitude: 26.7922,
        longitude: 82.1998,
        description: 'Urgent medical assistance required at Main Gate',
        broadcastRadiusMeters: 1500,
        dispatchedCount: 12,
        respondersCount: 3,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<SosBloc>(
            create: (_) => SosBloc(repository: mockRepo),
            child: ActiveSosScreen(sosEvent: testEvent),
          ),
        ),
      );

      await tester.pump();

      // Verify Active State Details
      expect(find.text('LIVE CIVIC SOS ACTIVE'), findsOneWidget);
      expect(find.text('MEDICAL EMERGENCY'), findsOneWidget);
      expect(find.text('Live on Network'), findsOneWidget);
      expect(find.text('Urgent medical assistance required at Main Gate'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Neighbors Alerted'), findsOneWidget);
      expect(find.text('1500m'), findsOneWidget);
      expect(find.text('Broadcast Radius'), findsOneWidget);
      expect(find.text('CANCEL / I AM SAFE'), findsOneWidget);
      expect(find.text('Offline Emergency (Dial 112 / SMS)'), findsOneWidget);

      // Scroll to ensure button is visible before tapping
      await tester.ensureVisible(find.text('CANCEL / I AM SAFE'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Cancel / I Am Safe Button to trigger confirm dialog
      await tester.tap(find.text('CANCEL / I AM SAFE'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Confirm Resolution'), findsOneWidget);
      expect(find.text('I Am Safe / Cancel SOS'), findsOneWidget);

      // Confirm safe resolution
      await tester.tap(find.text('I Am Safe / Cancel SOS'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockRepo.cancelCalled, isTrue);
    });
  });
}
