import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearo/core/theme/app_theme.dart';
import 'package:nearo/features/sos/presentation/bloc/sos_bloc.dart';
import 'package:nearo/features/sos/presentation/screens/sos_screen.dart';

void main() {
  group('Civic SOS Screen & Trigger Tests', () {
    testWidgets('SosScreen renders SOS Hold button and emergency categories',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<SosBloc>(
            create: (_) => SosBloc(),
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

      // Switch category selection
      await tester.tap(find.text('Medical Emergency'));
      await tester.pumpAndSettle();

      expect(find.text('Medical Emergency'), findsOneWidget);
    });
  });
}
