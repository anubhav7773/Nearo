import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearo/features/auth/domain/auth_repository.dart';
import 'package:nearo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nearo/features/auth/presentation/bloc/auth_event.dart';
import 'package:nearo/features/auth/presentation/bloc/auth_state.dart';
import 'package:nearo/features/auth/presentation/screens/login_screen.dart';
import 'package:nearo/features/auth/presentation/screens/phone_verification_screen.dart';

/// Stubs the Google SSO round-trip so widget tests never touch the
/// google_sign_in / firebase_auth platform channels.
class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository({
    Map<String, dynamic>? googleResult,
    Future<Map<String, dynamic>>? pendingGoogleResult,
    Map<String, dynamic>? profile,
  })  : _googleResult = googleResult ??
            const {
              'success': true,
              'user': {
                'id': 'fb_uid_resident_01',
                'email': 'resident.ayodhya@gmail.com',
                'alias_name': 'AyodhyaResident_04',
              },
            },
        _pendingGoogleResult = pendingGoogleResult,
        _profile = profile ?? const {'alias': 'AyodhyaResident_04', 'tier': 'free'};

  final Map<String, dynamic> _googleResult;
  final Future<Map<String, dynamic>>? _pendingGoogleResult;
  final Map<String, dynamic> _profile;

  bool signOutCalled = false;

  @override
  Future<Map<String, dynamic>> signInWithFirebaseGoogle({String? aliasName}) {
    return _pendingGoogleResult ?? Future.value(_googleResult);
  }

  @override
  Future<Map<String, dynamic>> signInWithGoogle({
    required String email,
    String? name,
    String? avatarUrl,
    String? idToken,
    String? clerkUserId,
  }) =>
      signInWithFirebaseGoogle(aliasName: name);

  @override
  Future<Map<String, dynamic>> syncUserProfile({
    String? clerkUserId,
    String? email,
    String? aliasName,
    String? avatarUrl,
    int? preferredRadiusMeters,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> getCurrentUser() async => _profile;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<bool> deleteAccount() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  Widget wrapWithBloc(Widget child, AuthBloc bloc) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(value: bloc, child: child),
    );
  }

  void sizeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('Google-only Login Screen', () {
    testWidgets('renders the premium brand header, Google CTA and subtext',
        (WidgetTester tester) async {
      sizeViewport(tester);
      final bloc = AuthBloc(authRepository: _StubAuthRepository());
      addTearDown(bloc.close);

      await tester.pumpWidget(
        wrapWithBloc(LoginScreen(onLoginSuccess: () {}), bloc),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Brand header
      expect(find.text('Nearo'), findsOneWidget);
      expect(find.text('Sajag Nagarik, Surakshit Mohalla'), findsOneWidget);
      expect(find.text('AN ASIVERTICALS INNOVATION'), findsOneWidget);

      // Primary action + subtext
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        find.text(
          'Instant sign-in for community alerts, civic feed & neighborhood safety.',
        ),
        findsOneWidget,
      );

      // DPDP trust signal
      expect(find.textContaining('DPDP Privacy Guaranteed'), findsOneWidget);
    });

    testWidgets('exposes no phone OTP or email/password affordances',
        (WidgetTester tester) async {
      sizeViewport(tester);
      final bloc = AuthBloc(authRepository: _StubAuthRepository());
      addTearDown(bloc.close);

      await tester.pumpWidget(
        wrapWithBloc(LoginScreen(onLoginSuccess: () {}), bloc),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Phone SMS OTP flow is permanently discontinued
      expect(find.text('Phone SMS OTP'), findsNothing);
      expect(find.text('Send SMS OTP'), findsNothing);
      expect(find.text('+91'), findsNothing);
      expect(find.byIcon(Icons.phone_android_rounded), findsNothing);
      expect(find.byIcon(Icons.dialpad_rounded), findsNothing);

      // No email/password tab on the sign-in surface
      expect(find.text('Email & Password'), findsNothing);
      expect(find.text('Password'), findsNothing);

      // Google SSO is the single action — no text inputs at all
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tapping the CTA swaps the label for an inline spinner',
        (WidgetTester tester) async {
      sizeViewport(tester);
      // A gated sign-in keeps the bloc parked in AuthLoading until we release it.
      final gate = Completer<Map<String, dynamic>>();
      final bloc = AuthBloc(
        authRepository: _StubAuthRepository(pendingGoogleResult: gate.future),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(
        wrapWithBloc(LoginScreen(onLoginSuccess: () {}), bloc),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(bloc.state, isA<AuthLoading>());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);

      // Release the gate — Bloc.close() awaits its in-flight emitters, so an
      // unresolved handler would hang teardown.
      gate.complete(const {'success': false, 'cancelled': true});
      await tester.pumpAndSettle();
    });

    testWidgets('surfaces an error banner when Google sign-in fails',
        (WidgetTester tester) async {
      sizeViewport(tester);
      final bloc = AuthBloc(
        authRepository: _StubAuthRepository(googleResult: const {
          'success': false,
          'error': 'Google sign-in did not return a valid Firebase ID token.',
        }),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(
        wrapWithBloc(LoginScreen(onLoginSuccess: () {}), bloc),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(bloc.state, isA<AuthFailure>());
      expect(
        find.text('Google sign-in did not return a valid Firebase ID token.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('a dismissed account chooser shows no error banner',
        (WidgetTester tester) async {
      sizeViewport(tester);
      final bloc = AuthBloc(
        authRepository: _StubAuthRepository(
          googleResult: const {'success': false, 'cancelled': true},
        ),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(
        wrapWithBloc(LoginScreen(onLoginSuccess: () {}), bloc),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(bloc.state, isA<AuthUnauthenticated>());
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('invokes onLoginSuccess once Google sign-in authenticates',
        (WidgetTester tester) async {
      sizeViewport(tester);
      final bloc = AuthBloc(authRepository: _StubAuthRepository());
      addTearDown(bloc.close);

      bool loginSuccessCalled = false;

      await tester.pumpWidget(
        wrapWithBloc(
          LoginScreen(onLoginSuccess: () => loginSuccessCalled = true),
          bloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(bloc.state, isA<AuthAuthenticated>());
      expect(loginSuccessCalled, isTrue);
    });
  });

  group('AuthBloc', () {
    test('exposes only Google sign-in, sign-out and status-check events', () {
      expect(GoogleSignInRequested(), isA<AuthEvent>());
      expect(SignOutRequested(), isA<AuthEvent>());
      expect(CheckAuthStatus(), isA<AuthEvent>());
    });

    test('CheckAuthStatus emits AuthUnauthenticated with no stored token',
        () async {
      FlutterSecureStorage.setMockInitialValues({});
      final bloc = AuthBloc(authRepository: _StubAuthRepository());
      addTearDown(bloc.close);

      bloc.add(CheckAuthStatus());

      await expectLater(
        bloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<AuthUnauthenticated>()]),
      );
    });

    test('CheckAuthStatus rehydrates the profile when a token is stored',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'firebase_id_token',
        'jwt_access_token': 'firebase_id_token',
      });
      final bloc = AuthBloc(
        authRepository: _StubAuthRepository(profile: const {
          'alias': 'AyodhyaResident_04',
          'email': 'resident.ayodhya@gmail.com',
          'tier': 'pro_resident',
        }),
      );
      addTearDown(bloc.close);

      bloc.add(CheckAuthStatus());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthAuthenticated>()
              .having((s) => s.aliasName, 'aliasName', 'AyodhyaResident_04')
              .having((s) => s.tier, 'tier', 'pro_resident'),
        ]),
      );
    });

    test('SignOutRequested revokes the session and emits AuthUnauthenticated',
        () async {
      final repository = _StubAuthRepository();
      final bloc = AuthBloc(authRepository: repository);
      addTearDown(bloc.close);

      bloc.add(SignOutRequested());

      await expectLater(bloc.stream, emitsInOrder([isA<AuthUnauthenticated>()]));
      expect(repository.signOutCalled, isTrue);
    });
  });

  group('PhoneVerificationScreen Mandatory Onboarding Tests', () {
    testWidgets('renders brand badge, DPDP privacy guarantee, and validates 10-digit number',
        (WidgetTester tester) async {
      sizeViewport(tester);
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            onVerificationComplete: () => completed = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verify Your Resident Mobile Number'), findsOneWidget);
      expect(find.text('AN ASIVERTICALS INNOVATION'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('🇮🇳'), findsOneWidget);
      expect(find.textContaining('DPDP Privacy Guaranteed'), findsOneWidget);
      expect(find.text('Continue to Neighborhood Network'), findsOneWidget);

      // Button should be disabled initially (empty input)
      final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(elevatedButton.onPressed, isNull);

      // Enter valid 10-digit Indian mobile number
      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.pump();

      expect(find.text('10/10'), findsOneWidget);

      // Button should be enabled now
      final enabledButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(enabledButton.onPressed, isNotNull);

      // Tap submit
      await tester.tap(find.text('Continue to Neighborhood Network'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(completed, isTrue);
    });
  });
}

