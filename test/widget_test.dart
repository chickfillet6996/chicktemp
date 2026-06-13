import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chicktemp/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {

    // Load the app
    await tester.pumpWidget(const ChickTempApp());

    // Check if the app loaded
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}