import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/report/report_controller.dart';
import 'package:project/services/report_service.dart';
import 'package:project/features/report/report_model.dart';

class MockReportService extends Mock implements ReportService {}

class TestReportService extends ReportServiceBase {
  final FakeFirebaseFirestore _firestore;

  TestReportService(this._firestore);

  @override
  Future<bool> checkReportExists(String reportId) async {
    final doc = await _firestore.collection('reports').doc(reportId).get();
    return doc.exists;
  }

  @override
  Future<void> confirmProblem(String reportId, String userId, bool confirmed) async {
    final confirmationDoc = _firestore
        .collection('problem_confirmations')
        .doc('${reportId}_$userId');
    final doc = await confirmationDoc.get();
    if (doc.exists) return;

    await confirmationDoc.set({
      'reportId': reportId,
      'userId': userId,
      'confirmed': confirmed,
    });

    final reportRef = _firestore.collection('reports').doc(reportId);
    if (confirmed) {
      await reportRef.update({'exists_confirmations': FieldValue.increment(1)});
    } else {
      await reportRef.update({'not_exists_confirmations': FieldValue.increment(1)});

      final reportDoc = await reportRef.get();
      final data = reportDoc.data();
      if (data != null) {
        final existsCount = (data['exists_confirmations'] as int?) ?? 0;
        final notExistsCount = (data['not_exists_confirmations'] as int?) ?? 0;
        if (existsCount * 1.25 + 5 < notExistsCount) {
          await reportRef.delete();
        }
      }
    }
  }

  @override
  Future<bool> hasUserConfirmed(String reportId, String userId) async {
    final doc = await _firestore
        .collection('problem_confirmations')
        .doc('${reportId}_$userId')
        .get();
    return doc.exists;
  }

  @override
  Future<void> deleteReport(ReportModel report) async {}

  @override
  Future<void> submitReport(ReportModel report, {File? photo}) async {}

  @override
  Stream<List<ReportModel>> watchReportsByUser(String uid) => Stream.value([]);
}

class FakeReportModel extends Fake implements ReportModel {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}


void main() {
  setUpAll(() {
    registerFallbackValue(FakeReportModel());
  });

  // original test - report submission
  testWidgets('Acceptance Test: User successfully reports a problem', (
    WidgetTester tester,
  ) async {
    // user is on the Report Screen
    // create a fake database service
    final mockService = MockReportService();
    final mockAuth = MockFirebaseAuth();
    final mockUser = MockUser();

    // tell fake database to return "Success" when asked to save
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('user123');
    when(
      () => mockService.submitReport(any(), photo: any(named: 'photo')),
    ).thenAnswer((_) async => Future.value());

    // create controller using fake database
    final controller = ReportController(service: mockService, auth: mockAuth);

    // simulate that the user has selected a category and location
    controller.selectedCategory = 'Pothole';
    controller.latitude = 41.5454;
    controller.longitude = -8.4265;

    // load screen with fake controller
    await tester.pumpWidget(
      MaterialApp(home: ReportScreen(controller: controller)),
    );

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
    verify(
      () => mockService.submitReport(any(), photo: any(named: 'photo')),
    ).called(1);

    // wait for animation to finish
    await tester.pumpAndSettle();
  });

  // confirmation feature tests
  group('ReportService confirmation methods', () {
    late FakeFirebaseFirestore firestore;
    late TestReportService reportService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      reportService = TestReportService(firestore);
    });

    // checkReportExists tests
    group('checkReportExists', () {
      // returns true when report exists
      test('returns true when report exists', () async {
        await firestore.collection('reports').doc('report1').set({
          'category': 'Pothole',
          'description': 'Test',
          'latitude': 38.7223,
          'longitude': -9.1393,
          'status': 'pending',
        });

        final exists = await reportService.checkReportExists('report1');

        expect(exists, isTrue);
      });

      // returns false when report does not exist
      test('returns false when report does not exist', () async {
        final exists = await reportService.checkReportExists('nonexistent');

        expect(exists, isFalse);
      });
    });

    // confirmProblem tests
    group('confirmProblem', () {
      // creates confirmation document when user confirms first time
      test('creates confirmation document', () async {
        await firestore.collection('reports').doc('report1').set({
          'category': 'Pothole',
          'description': 'Test',
          'latitude': 38.7223,
          'longitude': -9.1393,
          'status': 'pending',
        });

        await reportService.confirmProblem('report1', 'user1', true);

        final doc = await firestore
            .collection('problem_confirmations')
            .doc('report1_user1')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['confirmed'], isTrue);
      });

      // increments exists_confirmations when confirmed true
      test('increments exists_confirmations when confirmed', () async {
        await firestore.collection('reports').doc('report1').set({
          'category': 'Pothole',
          'description': 'Test',
          'latitude': 38.7223,
          'longitude': -9.1393,
          'status': 'pending',
        });

        await reportService.confirmProblem('report1', 'user1', true);

        final doc = await firestore.collection('reports').doc('report1').get();
        expect(doc.data()!['exists_confirmations'], equals(1));
      });

      // increments not_exists_confirmations when confirmed false
      test('increments not_exists_confirmations when not confirmed', () async {
        await firestore.collection('reports').doc('report1').set({
          'category': 'Pothole',
          'description': 'Test',
          'latitude': 38.7223,
          'longitude': -9.1393,
          'status': 'pending',
        });

        await reportService.confirmProblem('report1', 'user1', false);

        final doc = await firestore.collection('reports').doc('report1').get();
        expect(doc.data()!['not_exists_confirmations'], equals(1));
      });

      // does nothing when user already confirmed
      test('does nothing when user already confirmed', () async {
        await firestore.collection('reports').doc('report1').set({
          'category': 'Pothole',
          'description': 'Test',
          'latitude': 38.7223,
          'longitude': -9.1393,
          'status': 'pending',
          'exists_confirmations': 1,
        });
        await firestore.collection('problem_confirmations').doc('report1_user1').set({
          'reportId': 'report1',
          'userId': 'user1',
          'confirmed': true,
        });

        await reportService.confirmProblem('report1', 'user1', false);

        final doc = await firestore.collection('reports').doc('report1').get();
        expect(doc.data()!['exists_confirmations'], equals(1));
        expect(doc.data()!['not_exists_confirmations'], isNull);
      });

      // deletes report when formula triggers
      test('deletes report when formula triggers', () async {
        await firestore.collection('reports').doc('report1').set({
          'category': 'Pothole',
          'description': 'Test',
          'latitude': 38.7223,
          'longitude': -9.1393,
          'status': 'pending',
          'exists_confirmations': 8,
          'not_exists_confirmations': 15,
        });

        await reportService.confirmProblem('report1', 'user1', false);

        final doc = await firestore.collection('reports').doc('report1').get();
        expect(doc.exists, isFalse);
      });

      // does not delete report when formula does not trigger
      test('does not delete report when formula does not trigger', () async {
        await firestore.collection('reports').doc('report1').set({
          'category': 'Pothole',
          'description': 'Test',
          'latitude': 38.7223,
          'longitude': -9.1393,
          'status': 'pending',
          'exists_confirmations': 5,
          'not_exists_confirmations': 5,
        });

        await reportService.confirmProblem('report1', 'user1', false);

        final doc = await firestore.collection('reports').doc('report1').get();
        expect(doc.exists, isTrue);
      });
    });

    // hasUserConfirmed tests
    group('hasUserConfirmed', () {
      // returns true when user already confirmed
      test('returns true when user already confirmed', () async {
        await firestore.collection('problem_confirmations').doc('report1_user1').set({
          'reportId': 'report1',
          'userId': 'user1',
          'confirmed': true,
        });

        final hasConfirmed = await reportService.hasUserConfirmed('report1', 'user1');

        expect(hasConfirmed, isTrue);
      });

      // returns false when user has not confirmed
      test('returns false when user has not confirmed', () async {
        final hasConfirmed = await reportService.hasUserConfirmed('report1', 'user1');

        expect(hasConfirmed, isFalse);
      });
    });
  });
}
