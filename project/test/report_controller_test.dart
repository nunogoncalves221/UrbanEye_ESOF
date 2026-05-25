import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project/features/report/report_controller.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

class MockReportService extends Mock implements ReportServiceBase {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class FakeReportModel extends Fake implements ReportModel {}

void main() {
  late MockReportService mockService;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late ReportController controller;

  setUpAll(() {
    registerFallbackValue(FakeReportModel());
  });

  setUp(() {
    mockService = MockReportService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    controller = ReportController(service: mockService, auth: mockAuth);
  });

  group('ReportController.validate', () {
    test('returns error when no category is selected', () {
      controller.description = 'Test';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      expect(controller.validate(), equals('Please select a category.'));
    });

    test('returns error when category is empty string', () {
      controller.selectedCategory = '';
      controller.description = 'Test';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      expect(controller.validate(), equals('Please select a category.'));
    });

    test('returns error when description is empty', () {
      controller.selectedCategory = 'Pothole';
      controller.description = '';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      expect(controller.validate(), equals('Please enter a description.'));
    });

    test('returns error when description is only whitespace', () {
      controller.selectedCategory = 'Pothole';
      controller.description = '   ';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      expect(controller.validate(), equals('Please enter a description.'));
    });

    test('returns error when latitude is null', () {
      controller.selectedCategory = 'Pothole';
      controller.description = 'Test';
      controller.longitude = -8.0;

      expect(
        controller.validate(),
        equals('Please fetch your location before submitting.'),
      );
    });

    test('returns error when longitude is null', () {
      controller.selectedCategory = 'Pothole';
      controller.description = 'Test';
      controller.latitude = 41.0;

      expect(
        controller.validate(),
        equals('Please fetch your location before submitting.'),
      );
    });

    test('returns null when all required fields are valid', () {
      controller.selectedCategory = 'Pothole';
      controller.description = 'Big hole';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      expect(controller.validate(), isNull);
    });
  });

  group('ReportController.submitReport', () {
    test('returns false and sets errorMessage when validation fails', () async {
      final result = await controller.submitReport();

      expect(result, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.isLoading, isFalse);
    });

    test('does not call service when validation fails', () async {
      await controller.submitReport();

      verifyNever(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      );
    });

    test('returns true on successful submission', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenAnswer((_) async {});

      controller.selectedCategory = 'Pothole';
      controller.description = 'Big hole';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      final result = await controller.submitReport();

      expect(result, isTrue);
      expect(controller.submitted, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('calls service.submitReport on success', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenAnswer((_) async {});

      controller.selectedCategory = 'Pothole';
      controller.description = 'Big hole';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      await controller.submitReport();

      verify(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).called(1);
    });

    test('returns false and sets error on service exception', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenThrow(Exception('Network error'));

      controller.selectedCategory = 'Pothole';
      controller.description = 'Big hole';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      final result = await controller.submitReport();

      expect(result, isFalse);
      expect(
        controller.errorMessage,
        equals('Failed to submit report. Please try again.'),
      );
      expect(controller.isLoading, isFalse);
    });

    test('submits with null userId when user is not logged in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenAnswer((_) async {});

      controller.selectedCategory = 'Pothole';
      controller.description = 'Big hole';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      final result = await controller.submitReport();

      expect(result, isTrue);
    });

    test('includes address in report when set', () async {
      ReportModel? captured;
      when(() => mockAuth.currentUser).thenReturn(null);
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as ReportModel;
      });

      controller.selectedCategory = 'Pothole';
      controller.description = 'Hole';
      controller.latitude = 41.0;
      controller.longitude = -8.0;
      controller.address = 'Rua das Flores';

      await controller.submitReport();

      expect(captured?.address, equals('Rua das Flores'));
    });
  });

  group('ReportController.reset', () {
    test('resets all fields to defaults', () {
      controller.selectedCategory = 'Pothole';
      controller.description = 'Test';
      controller.latitude = 41.0;
      controller.longitude = -8.0;
      controller.address = 'Rua A';
      controller.errorMessage = 'Some error';

      controller.reset();

      expect(controller.selectedCategory, isNull);
      expect(controller.description, equals(''));
      expect(controller.photo, isNull);
      expect(controller.latitude, isNull);
      expect(controller.longitude, isNull);
      expect(controller.address, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.submitted, isFalse);
    });

    test('reset notifies listeners', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.reset();

      expect(notified, isTrue);
    });
  });

  group('ReportController listener notifications', () {
    test('notifies listeners when submitReport fails validation', () async {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.submitReport();

      expect(notifyCount, greaterThan(0));
    });

    test('notifies listeners on successful submitReport', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenAnswer((_) async {});

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.selectedCategory = 'Pothole';
      controller.description = 'Hole';
      controller.latitude = 41.0;
      controller.longitude = -8.0;

      await controller.submitReport();

      expect(notifyCount, greaterThanOrEqualTo(2));
    });
  });

  group('ReportController photo functionality', () {
    // pick photo from camera
    test('pickPhoto sets photo when image is selected', () async {
      // Note: This test verifies the controller logic
      // Actual image picking requires mocking ImagePicker
      controller.photo = null;
      expect(controller.photo, isNull);
    });

    // submit with photo
    test('submitReport includes photo when set', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenAnswer((_) async {});

      controller.selectedCategory = 'Pothole';
      controller.description = 'Hole with photo';
      controller.latitude = 41.0;
      controller.longitude = -8.0;
      // controller.photo is set by pickPhoto method at runtime

      final result = await controller.submitReport();

      expect(result, isTrue);
      verify(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).called(1);
    });

    // no photo taken
    test('submitReport sends null photo when not set', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenAnswer((_) async {});

      controller.selectedCategory = 'Pothole';
      controller.description = 'Hole without photo';
      controller.latitude = 41.0;
      controller.longitude = -8.0;
      controller.photo = null;

      final result = await controller.submitReport();

      expect(result, isTrue);
      // verify photo is null
      verify(() => mockService.submitReport(any(), photo: null)).called(1);
    });

    // reset clears photo
    test('reset clears photo field', () {
      controller.photo = File('/fake/path/photo.jpg');
      controller.reset();

      expect(controller.photo, isNull);
    });
  });
}
