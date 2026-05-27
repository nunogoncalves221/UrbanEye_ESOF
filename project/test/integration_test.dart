// Integration Tests
//
// Tests that verify the interaction between multiple components
// (ReportController + ReportService + Fake Firestore)
// Uses FakeFirebaseFirestore to simulate the real database

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project/config/cloudinary_config.dart';
import 'package:project/features/notifications/notification_model.dart';
import 'package:project/features/report/report_controller.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/cloudinary_service.dart';
import 'package:project/services/points_service.dart';
import 'package:project/services/notification_service.dart';
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

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
    String reportId,
    String userId,
    bool confirmed,
  ) async {
    final confirmationDoc = _firestore
        .collection('problem_confirmations')
        .doc('${reportId}_$userId');
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

  @override
  Future<void> confirmReportByAuthority(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'authority_confirmed': true,
    });
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

    test('submitReport saves report without photo to Firestore', () async {
      final controller = ReportController(service: service, auth: mockAuth);
      controller.selectedCategory = 'Pothole';
      controller.description = 'Test hole';
      controller.latitude = 41.15;
      controller.longitude = -8.61;
      controller.photo = null;

      final result = await controller.submitReport();

      expect(result, isTrue);
      final snapshot = await firestore.collection('reports').get();
      expect(snapshot.docs.length, equals(1));
      final savedReport = snapshot.docs.first.data();
      expect(savedReport['category'], equals('Pothole'));
      expect(savedReport['description'], equals('Test hole'));
      expect(savedReport['photoUrl'], isNull);
    });

    test('submitReport saves report with photo URL to Firestore', () async {
      final controller = ReportController(service: service, auth: mockAuth);
      controller.selectedCategory = 'Streetlight';
      controller.description = 'Broken light';
      controller.latitude = 41.15;
      controller.longitude = -8.61;
      controller.photo = File('/fake/path/photo.jpg');

      final result = await controller.submitReport();

      expect(result, isTrue);
      final snapshot = await firestore.collection('reports').get();
      expect(snapshot.docs.length, equals(1));
      expect(snapshot.docs.first.data()['photoUrl'], isNotNull);
    });

    test('watchReportsByUser returns reports for specific user', () async {
      await firestore.collection('reports').doc('r1').set({
        'category': 'Pothole', 'description': 'Test 1',
        'latitude': 41.0, 'longitude': -8.0,
        'userId': 'test_user_123', 'status': 'pending',
        'createdAt': Timestamp.now(),
        'exists_confirmations': 0, 'not_exists_confirmations': 0,
      });
      await firestore.collection('reports').doc('r2').set({
        'category': 'Trash', 'description': 'Test 2',
        'latitude': 41.1, 'longitude': -8.1,
        'userId': 'other_user', 'status': 'pending',
        'createdAt': Timestamp.now(),
        'exists_confirmations': 0, 'not_exists_confirmations': 0,
      });

      final reports = await service.getReportsByUser('test_user_123');

      expect(reports.length, equals(1));
      expect(reports.first.category, equals('Pothole'));
    });

    test('deleteReport removes report from Firestore', () async {
      await firestore.collection('reports').doc('r1').set({
        'category': 'Pothole', 'description': 'To be deleted',
        'latitude': 41.0, 'longitude': -8.0,
        'userId': 'test_user_123', 'status': 'pending',
        'createdAt': Timestamp.now(),
        'exists_confirmations': 0, 'not_exists_confirmations': 0,
      });

      final report = ReportModel(
        id: 'r1', category: 'Pothole', description: 'To be deleted',
        latitude: 41.0, longitude: -8.0,
        userId: 'test_user_123', status: 'pending',
      );

      await service.deleteReport(report);

      final doc = await firestore.collection('reports').doc('r1').get();
      expect(doc.exists, isFalse);
    });
  });

  // ── PointsService + ReportService ─────────────────────────────────────────
  //
  // Tests that verify the two services work correctly together:
  // ReportService triggers PointsService at the right moments and both
  // Firestore collections (users + points_history) end up in the expected state.

  group('Integration: PointsService + ReportService', () {
    late FakeFirebaseFirestore firestore;
    late ReportService reportService;
    late PointsService pointsService;

    Future<String> seedReport(String reporterId) async {
      final ref = firestore.collection('reports').doc();
      await ref.set({'userId': reporterId, 'status': 'pending', 'points_awarded': false});
      return ref.id;
    }

    Future<void> seedUser(String uid, {int points = 0}) async {
      await firestore.collection('users').doc(uid).set({'points': points});
    }

    Future<int> getPoints(String uid) async {
      final doc = await firestore.collection('users').doc(uid).get();
      return (doc.data()?['points'] as int?) ?? 0;
    }

    Future<int> historyCount(String uid) async {
      final snap = await firestore
          .collection('points_history')
          .where('userId', isEqualTo: uid)
          .get();
      return snap.docs.length;
    }

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      reportService = ReportService(firestore: firestore);
      pointsService = PointsService(firestore: firestore);
      for (final uid in ['reporter-1', 'confirmer-1', 'confirmer-2']) {
        await seedUser(uid);
      }
    });

    test(
      'IT-01 | confirmar report dá +1 ao confirmer e +2 ao reporter',
      () async {
        final reportId = await seedReport('reporter-1');

        await reportService.confirmProblem(reportId, 'confirmer-1', true);

        expect(await getPoints('confirmer-1'), equals(1));
        expect(await getPoints('reporter-1'), equals(2));
      },
    );

    test(
      'IT-02 | confirmar report cria entradas no histórico para ambos',
      () async {
        final reportId = await seedReport('reporter-1');

        await reportService.confirmProblem(reportId, 'confirmer-1', true);

        expect(await historyCount('confirmer-1'), equals(1));
        expect(await historyCount('reporter-1'), equals(1));
      },
    );

    test(
      'IT-03 | resolver report dá +10 ao reporter e cria entrada no histórico',
      () async {
        final reportId = await seedReport('reporter-1');

        await pointsService.onReportResolved(reportId, 'reporter-1');

        expect(await getPoints('reporter-1'), equals(10));
        expect(await historyCount('reporter-1'), equals(1));
      },
    );

    test(
      'IT-04 | resolver o mesmo report duas vezes só dá pontos uma vez',
      () async {
        final reportId = await seedReport('reporter-1');

        await pointsService.onReportResolved(reportId, 'reporter-1');
        await pointsService.onReportResolved(reportId, 'reporter-1');

        expect(await getPoints('reporter-1'), equals(10));
        expect(await historyCount('reporter-1'), equals(1));
      },
    );

    test(
      'IT-05 | rejeitar report deduz 5 pontos ao reporter e cria entrada no histórico',
      () async {
        await seedUser('reporter-1', points: 20);

        await pointsService.onReportRejected('reporter-1');

        expect(await getPoints('reporter-1'), equals(15));
        expect(await historyCount('reporter-1'), equals(1));
      },
    );

    test(
      'IT-06 | várias confirmações acumulam pontos corretamente no reporter',
      () async {
        final reportId = await seedReport('reporter-1');

        await reportService.confirmProblem(reportId, 'confirmer-1', true);
        await reportService.confirmProblem(reportId, 'confirmer-2', true);

        expect(await getPoints('reporter-1'), equals(4));
        expect(await getPoints('confirmer-1'), equals(1));
        expect(await getPoints('confirmer-2'), equals(1));
      },
    );

    test(
      'IT-07 | pontos de confirmação e resolução acumulam-se independentemente',
      () async {
        final reportId = await seedReport('reporter-1');

        await reportService.confirmProblem(reportId, 'confirmer-1', true);
        await pointsService.onReportResolved(reportId, 'reporter-1');

        expect(await getPoints('reporter-1'), equals(12));
        expect(await historyCount('reporter-1'), equals(2));
      },
    );
  });

  group('CloudinaryService Integration', () {
    late CloudinaryService cloudinary;

    setUp(() {
      cloudinary = const CloudinaryService();
    });

    test('uploadPhoto returns valid secure_url with cloud domain', () async {
      final testImageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
      );
      final tempFile = File('${Directory.systemTemp.path}/cloudinary_test_photo.png');
      await tempFile.writeAsBytes(testImageBytes);
      try {
        final reportId = 'test-${DateTime.now().millisecondsSinceEpoch}';
        final url = await cloudinary.uploadPhoto(tempFile, reportId);
        final publicId = CloudinaryService.extractPublicIdFromUrl(url!);
        expect(url, isNotNull);
        expect(url, contains('res.cloudinary.com/${CloudinaryConfig.cloudName}'));
        await cloudinary.deletePhoto(publicId);
      } finally {
        await tempFile.delete();
      }
    });

    test('uploadPhoto extracts correct public ID format', () async {
      final testImageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
      );
      final tempFile = File('${Directory.systemTemp.path}/cloudinary_test_photo2.png');
      await tempFile.writeAsBytes(testImageBytes);
      try {
        final reportId = 'test-${DateTime.now().millisecondsSinceEpoch}';
        final url = await cloudinary.uploadPhoto(tempFile, reportId);
        final publicId = CloudinaryService.extractPublicIdFromUrl(url!);
        expect(publicId, startsWith('reports/$reportId'));
        expect(publicId, isNotEmpty);
        await cloudinary.deletePhoto(publicId);
      } finally {
        await tempFile.delete();
      }
    });

    test('deletePhoto removes photo from cloud', () async {
      final testImageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
      );
      final tempFile = File('${Directory.systemTemp.path}/cloudinary_test_photo3.png');
      await tempFile.writeAsBytes(testImageBytes);
      try {
        final reportId = 'test-${DateTime.now().millisecondsSinceEpoch}';
        final url = await cloudinary.uploadPhoto(tempFile, reportId);
        final publicId = CloudinaryService.extractPublicIdFromUrl(url!);
        await cloudinary.deletePhoto(publicId);
        await cloudinary.deletePhoto(publicId);
      } finally {
        await tempFile.delete();
      }
    });

    test('deletePhoto handles non-existent public ID gracefully', () async {
      await expectLater(
        () => cloudinary.deletePhoto('reports/nonexistent-test-id-xyz'),
        returnsNormally,
      );
    });

    test('upload then delete cleans up properly', () async {
      final testImageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
      );
      final tempFile = File('${Directory.systemTemp.path}/cloudinary_test_photo4.png');
      await tempFile.writeAsBytes(testImageBytes);
      try {
        final reportId = 'test-${DateTime.now().millisecondsSinceEpoch}';
        final url = await cloudinary.uploadPhoto(tempFile, reportId);
        final publicId = CloudinaryService.extractPublicIdFromUrl(url!);
        await cloudinary.deletePhoto(publicId);
        await cloudinary.deletePhoto(publicId);
      } finally {
        await tempFile.delete();
      }
    });
  });

  // ── NotificationService ───────────────────────────────────────────────────

  group('Integration: NotificationService + Firestore', () {
    late FakeFirebaseFirestore firestore;
    late NotificationService notificationService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      notificationService = NotificationService(firestore: firestore);
    });

    test('NT-I-01 | notificação criada aparece no stream do dono', () async {
      await notificationService.notifyReportChange(
        reportId: 'rep_1',
        reportCategory: 'roads',
        type: 'status_change',
        message: 'O teu report mudou de estado.',
        reportOwnerId: 'user_owner',
      );

      final list = await notificationService
          .watchNotificationsForUser('user_owner')
          .first;

      expect(list.length, 1);
      expect(list.first.message, 'O teu report mudou de estado.');
      expect(list.first.isRead, false);
    });

    test('NT-I-02 | markAsRead — notificação aparece como lida no stream', () async {
      final docRef = await firestore.collection('notifications').add({
        'userId': 'user_1', 'reportId': 'r', 'reportCategory': 'c',
        'type': 'status_change', 'message': 'msg', 'isRead': false, 'createdAt': null,
      });

      await notificationService.markAsRead(docRef.id);

      final list = await notificationService
          .watchNotificationsForUser('user_1')
          .first;
      expect(list.first.isRead, true);
    });

    test('NT-I-03 | markAllAsRead — todas as notificações ficam lidas', () async {
      for (var i = 0; i < 3; i++) {
        await firestore.collection('notifications').add({
          'userId': 'user_2', 'reportId': 'r$i', 'reportCategory': 'c',
          'type': 'status_change', 'message': 'msg$i', 'isRead': false, 'createdAt': null,
        });
      }

      await notificationService.markAllAsRead('user_2');

      final list = await notificationService
          .watchNotificationsForUser('user_2')
          .first;
      expect(list.every((n) => n.isRead), isTrue);
    });
  });
}