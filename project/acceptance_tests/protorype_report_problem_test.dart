import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/report_problem.dart'; 

void main() {
  //Check if the UI renders correctly
  testWidgets('Report Problem screen loads all UI elements', (WidgetTester tester) async {

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportProblemPrototype(),
      ),
    );

    expect(find.text('Report a Problem'), findsOneWidget); //title
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('SUBMIT REPORT'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  //Check if the user can type in the description box
  testWidgets('User can type into the description field', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportProblemPrototype(),
      ),
    );

    final descriptionField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Enter details about the problem here...'
    );

    expect(descriptionField, findsOneWidget);

    await tester.enterText(descriptionField, 'There is a huge pothole on my street.');

    expect(find.text('There is a huge pothole on my street.'), findsOneWidget);
  });
}