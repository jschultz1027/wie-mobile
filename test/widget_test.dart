// Basic smoke test for the WIE Mobile app.
//
// The app boots into a SplashScreen (wrapped in providers). This test verifies
// that the root widget builds without throwing and renders a MaterialApp.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wie_mobile/main.dart';

void main() {
  testWidgets('App boots and renders a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // A single frame is enough to confirm the widget tree builds. We avoid
    // pumpAndSettle() because the splash screen runs timers/animations.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
