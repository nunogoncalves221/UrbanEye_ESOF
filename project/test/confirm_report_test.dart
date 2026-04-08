import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/main.dart';

void main() {
  // IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Confirm reported problem exists', (tester) async {
    await tester.pumpWidget(const MainApp());

    // Open an existing report
    await tester.tap(find.byKey(const Key('report_item_0')));
    await tester.pumpAndSettle();

    // Confirm that the problem exists
    await tester.tap(find.byKey(const Key('confirmExistsButton')));
    await tester.pumpAndSettle();

    // Check if the report is still active
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('Deny reported problem once', (tester) async {
    await tester.pumpWidget(const MainApp());

    // Open an existing report
    await tester.tap(find.byKey(const Key('report_item_0')));
    await tester.pumpAndSettle();

    // Deny that the problem exists
    await tester.tap(find.byKey(const Key('denyExistsButton')));
    await tester.pumpAndSettle();

    // Check if the report is still active (one denial is not enough)
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('Report is removed after many denials', (tester) async {
    await tester.pumpWidget(const MainApp());

    // Open an existing report
    await tester.tap(find.byKey(const Key('report_item_0')));
    await tester.pumpAndSettle();

    // Simulate many users denying the problem
    for (int i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('denyExistsButton')));
      await tester.pumpAndSettle();
    }

    // Check if the report no longer exists
    expect(find.text('Report does not exist'), findsOneWidget);
  });
}