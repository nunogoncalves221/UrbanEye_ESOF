// Integration Tests
//
// Tests that verify the interaction between multiple components
// (ReportController + ReportService + Fake Firestore)
// Uses FakeFirebaseFirestore to simulate the real database

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project/features/report/report_controller.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class FakeReportModel extends Fake implements ReportModel {}

class TestReportService extends ReportServiceBase {
  final FakeFirebaseFirestore _firestore;

  TestReportService(this._firestore);

  @override
  Future<void> submitReport(ReportModel report, {File? photo}) async {
    final docRef = _firestore.collection('reports').doc();
    final finalReport = ReportModel(
      id: docRef.id,
      category: report.category,
      description: report.description,
      latitude: report.latitude,
      longitude: report.longitude,
      photoUrl: photo != null ? 'photo_url_placeholder' : null,
      userId: report.userId,
      status: report.status,
      createdAt: report.createdAt,
    );
    await docRef.set(finalReport.toMap());
  }

  @override
  Stream<List<ReportModel>> watchReportsByUser(String uid) {
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<List<ReportModel>> getReportsByUser(String userId) async {
    final snapshot = await _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> deleteReport(ReportModel report) async {
    await _firestore.collection('reports').doc(report.id).delete();
  }

  @override
  Future<bool> checkReportExists(String reportId) async {
    final doc = await _firestore.collection('reports').doc(reportId).get();
    return doc.exists;
  }

  @override
  Future<void> confirmProblem(
      String reportId, String userId, bool confirmed) async {
    final confirmationDoc =
        _firestore.collection('problem_confirmations').doc('${reportId}_$userId');
    await confirmationDoc.set({
      'reportId': reportId,
      'userId': userId,
      'confirmed': confirmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> hasUserConfirmed(String reportId, String userId) async {
    final doc = await _firestore
        .collection('problem_confirmations')
        .doc('${reportId}_$userId')
        .get();
    return doc.exists;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeReportModel());
  });

  group('Integration: ReportController + ReportService', () {
    late FakeFirebaseFirestore firestore;
    late TestReportService service;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = TestReportService(firestore);
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test_user_123');
    });

    // submit report without photo
    test('submitReport saves report without photo to Firestore', () async {
      final controller = ReportController(service: service, auth: mockAuth);
      controller.selectedCategory = 'Pothole';
      controller.description = 'Test hole';
      controller.latitude = 41.15;
      controller.longitude = -8.61;
      controller.photo = null;

      final result = await controller.submitReport();

      expect(result, isTrue);

      // verify report was saved
      final snapshot = await firestore.collection('reports').get();
      expect(snapshot.docs.length, equals(1));
      final savedReport = snapshot.docs.first.data();
      expect(savedReport['category'], equals('Pothole'));
      expect(savedReport['description'], equals('Test hole'));
      // check for photo - should be null
      expect(savedReport['photoUrl'], isNull);
    });

    // submit report with photo
    test('submitReport saves report with photo URL to Firestore', () async {
      final controller = ReportController(service: service, auth: mockAuth);
      controller.selectedCategory = 'Streetlight';
      controller.description = 'Broken light';
      controller.latitude = 41.15;
      controller.longitude = -8.61;
      // photo is set (simulated - actual file not uploaded in test)
      controller.photo = File('/fake/path/photo.jpg');

      final result = await controller.submitReport();

      expect(result, isTrue);

      // verify report was saved with photo URL
      final snapshot = await firestore.collection('reports').get();
      expect(snapshot.docs.length, equals(1));
      final savedReport = snapshot.docs.first.data();
      expect(savedReport['category'], equals('Streetlight'));
      // photo taken - URL should be set
      expect(savedReport['photoUrl'], isNotNull);
    });

    // watch reports by user
    test('watchReportsByUser returns reports for specific user', () async {
      // save some test reports
      await firestore.collection('reports').doc('r1').set({
        'category': 'Pothole',
        'description': 'Test 1',
        'latitude': 41.0,
        'longitude': -8.0,
        'userId': 'test_user_123',
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'exists_confirmations': 0,
        'not_exists_confirmations': 0,
      });
      await firestore.collection('reports').doc('r2').set({
        'category': 'Trash',
        'description': 'Test 2',
        'latitude': 41.1,
        'longitude': -8.1,
        'userId': 'other_user',
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'exists_confirmations': 0,
        'not_exists_confirmations': 0,
      });

      final reports = await service.getReportsByUser('test_user_123');

      expect(reports.length, equals(1));
      expect(reports.first.category, equals('Pothole'));
    });

    // delete report
    test('deleteReport removes report from Firestore', () async {
      // save a report first
      await firestore.collection('reports').doc('r1').set({
        'category': 'Pothole',
        'description': 'To be deleted',
        'latitude': 41.0,
        'longitude': -8.0,
        'userId': 'test_user_123',
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'exists_confirmations': 0,
        'not_exists_confirmations': 0,
      });

      final report = ReportModel(
        id: 'r1',
        category: 'Pothole',
        description: 'To be deleted',
        latitude: 41.0,
        longitude: -8.0,
        userId: 'test_user_123',
        status: 'pending',
      );

      await service.deleteReport(report);

      final doc = await firestore.collection('reports').doc('r1').get();
      expect(doc.exists, isFalse);
    });
  });
}