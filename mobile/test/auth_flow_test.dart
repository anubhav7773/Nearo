import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearo/features/auth/presentation/screens/otp_login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  const MethodChannel googleSignInChannel =
      MethodChannel('plugins.flutter.io/google_sign_in');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(googleSignInChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'init' || methodCall.method == 'signIn') {
        return <String, dynamic>{
          'displayName': 'Ayodhya Resident',
          'email': 'resident.ayodhya@gmail.com',
          'id': 'g7a99c82-849e-4e4a-b5e2-74b12903a918',
          'photoUrl': 'https://lh3.googleusercontent.com/a/avatar',
          'idToken': 'mock_google_id_token',
        };
      }
      return null;
    });
  });

  group('Firebase Phone OTP, Google One-Tap & Email Auth Flow Tests', () {
    testWidgets(
        'OtpLoginScreen renders Google button, Phone tab, Email tab, and DPDP privacy notice',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool loginSuccessCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OtpLoginScreen(
            onLoginSuccess: () {
              loginSuccessCalled = true;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Brand & Header
      expect(find.text('Nearo'), findsOneWidget);
      expect(find.text('Welcome Resident'), findsOneWidget);

      // Verify Google SSO Button
      expect(find.text('Continue with Google'), findsOneWidget);

      // Verify 2 Tabs exist (Phone SMS and Email)
      expect(find.byIcon(Icons.phone_android_rounded), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);

      // Verify Phone Tab is active by default
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Send SMS OTP'), findsOneWidget);

      // Verify DPDP Privacy Guarantee
      expect(
        find.textContaining('DPDP Privacy Guaranteed'),
        findsOneWidget,
      );

      // Tap Google SSO button
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(loginSuccessCalled, isTrue);
    });

    testWidgets('Switch to Email & Password tab and verify inputs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: OtpLoginScreen(
            onLoginSuccess: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Email tab by tapping its tab icon
      await tester.tap(find.byIcon(Icons.email_outlined));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Email & Password fields
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('New resident? Create Account'), findsOneWidget);
    });
  });
}
