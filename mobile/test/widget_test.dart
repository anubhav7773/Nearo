import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearo/main.dart';

void main() {
  testWidgets('NearoApp initial frame smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NearoApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
