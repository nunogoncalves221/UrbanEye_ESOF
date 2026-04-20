import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/report/report_controller.dart';
import 'package:project/services/report_service.dart';
import 'package:project/features/report/report_model.dart';

class MockReportService extends Mock implements ReportService {}
class FakeReportModel extends Fake implements ReportModel {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
    setUpAll(() {
    registerFallbackValue(FakeReportModel());
  });

  testWidgets('Acceptance Test: User successfully reports a problem', (WidgetTester tester) async {
    
    // user is on the Report Screen
    // create a fake database service
    final mockService = MockReportService();
    final mockAuth = MockFirebaseAuth();
    final mockUser = MockUser();
    
    // tell fake database to return "Success" when asked to save
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('user123');
    when(() => mockService.submitReport(any(), photo: any(named: 'photo')))
        .thenAnswer((_) async => Future.value());

    // create controller using fake database
    final controller = ReportController(service: mockService, auth: mockAuth);
    
    // simulate that the user has selected a category and location 
    controller.selectedCategory = 'Pothole';
    controller.latitude = 41.5454;
    controller.longitude = -8.4265;

    // load screen with fake controller
    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(controller: controller),
    ));

    // fill details and tap submit    
    // find the description text field and type into it
    final descriptionField = find.byType(TextField).last;
    await tester.enterText(descriptionField, 'There is a huge pothole here!');

    // find submit button and tap it
    final submitButton = find.text('SUBMIT REPORT');
    await tester.tap(submitButton);
    
    // start animation and wait snackbar to appear
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // verify success message
    expect(find.text('Report submitted successfully!'), findsOneWidget);
       
    // verify fake database was called exactly 1 time
    verify(() => mockService.submitReport(any(), photo: any(named: 'photo'))).called(1);

    // wait for animation to finish
    await tester.pumpAndSettle();
  });
}