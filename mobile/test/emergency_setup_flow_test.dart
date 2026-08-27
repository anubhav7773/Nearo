import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nearo/core/network/secure_storage.dart';
import 'package:nearo/features/auth/presentation/screens/emergency_setup_screen.dart';
import 'package:nearo/features/sos/utils/offline_sos_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Emergency Contact Setup E2E & Edge Case Tests', () {
    testWidgets('EmergencySetupScreen renders form elements and validation errors', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: EmergencySetupScreen(
            onSetupComplete: () {
              completed = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify initial UI elements
      expect(find.text('Emergency Contact Setup'), findsOneWidget);
      expect(find.text('Set Your Primary Emergency Contact'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Save Emergency Contact'), findsOneWidget);

      // 2. Test Invalid Indian phone number (starts with 1)
      await tester.enterText(find.byType(TextFormField).at(1), '1234567890');
      await tester.pumpAndSettle();
      expect(find.text('Indian numbers must start with 6, 7, 8, or 9'), findsOneWidget);

      // 3. Test Incomplete phone number (less than 10 digits)
      await tester.enterText(find.byType(TextFormField).at(1), '98765');
      await tester.pumpAndSettle();
      expect(find.text('Enter 10-digit number'), findsOneWidget);

      // 4. Test Valid Indian phone number
      await tester.enterText(find.byType(TextFormField).at(0), 'Father');
      await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
      await tester.pumpAndSettle();

      // 5. Submit valid contact
      final submitButton = find.text('Save Emergency Contact');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(completed, isTrue);

      // Verify secure storage state
      final savedPhone = await SecureStorageService.getEmergencyContactPhone();
      final savedName = await SecureStorageService.getEmergencyContactName();
      expect(savedPhone, equals('+919876543210'));
      expect(savedName, equals('Father'));
      expect(await SecureStorageService.hasEmergencyContact(), isTrue);
    });

    test('SecureStorageService emergency contact reset state flow', () async {
      await SecureStorageService.saveEmergencyContactPhone('+919988776655');
      await SecureStorageService.saveEmergencyContactName('Brother');
      expect(await SecureStorageService.hasEmergencyContact(), isTrue);

      // Reset
      await SecureStorageService.clearEmergencyContact();
      expect(await SecureStorageService.getEmergencyContactPhone(), isNull);
      expect(await SecureStorageService.getEmergencyContactName(), isNull);
      expect(await SecureStorageService.hasEmergencyContact(), isFalse);
    });

    test('OfflineSosHelper strict recipient validation aborts untargeted SMS', () async {
      await SecureStorageService.clearEmergencyContact();

      // Dispatch without configured contact must abort immediately
      final dispatched = await OfflineSosHelper.triggerOfflineSms(
        category: 'security',
        latitude: 26.7922,
        longitude: 82.1998,
      );

      expect(dispatched, isFalse);
    });
  });
}
