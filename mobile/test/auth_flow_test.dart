import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearo/features/auth/presentation/screens/otp_login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Email OTP & Google SSO Auth Flow Tests', () {
    testWidgets(
        'OtpLoginScreen renders Google button, Email input, and Privacy notice',
        (WidgetTester tester) async {
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

      // Verify Google SSO Button
      expect(find.text('Continue with Google'), findsOneWidget);

      // Verify Email Address input field & Send Verification Code button
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);

      // Verify Zero-Knowledge Privacy Guarantee
      expect(
        find.textContaining('Zero-Knowledge Privacy: Your email is encrypted'),
        findsOneWidget,
      );

      // Verify NO phone number SMS fields exist
      expect(find.text('Mobile Number'), findsNothing);
      expect(find.text('+91 '), findsNothing);

      // Tap Google SSO button
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(loginSuccessCalled, isTrue);
    });
  });
}
