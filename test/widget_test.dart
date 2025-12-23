// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:dot_matrix/main.dart';

void main() {
  testWidgets('Material Layering App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialLayeringApp());

    // Verify that the app title is displayed
    expect(find.text('Material Layering System'), findsOneWidget);

    // Verify that the initial status is displayed
    expect(find.text('No Model'), findsOneWidget);
  });
}
