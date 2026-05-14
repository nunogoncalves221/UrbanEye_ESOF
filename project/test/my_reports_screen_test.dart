import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/report/my_reports_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;
  FakeFirebaseAuth(this._user);

  @override
  User? get currentUser => _user;
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'user123';

  @override
  String get email => 'test@example.com';
}

class FakeReportService extends ReportServiceBase {
  final List<ReportModel> reports;
  final Stream<List<ReportModel>>? _stream;
  bool deleteWasCalled = false;
  bool deleteShouldThrow = false;

  FakeReportService({
    this.reports = const [],
    Stream<List<ReportModel>>? stream,
  }) : _stream = stream;

  @override
  Stream<List<ReportModel>> watchReportsByUser(String uid) =>
      _stream ?? Stream.value(reports);

  @override
  Future<void> deleteReport(ReportModel report) async {
    deleteWasCalled = true;
    if (deleteShouldThrow) throw Exception('Delete failed');
  }

  @override
  Future<void> submitReport(ReportModel report, {File? photo}) async {}

  @override
  Future<bool> checkReportExists(String reportId) async => true;

  @override
  Future<void> confirmProblem(
    String reportId,
    String userId,
    bool confirmed,
  ) async {}

  @override
  Future<bool> hasUserConfirmed(String reportId, String userId) async => false;
}

ReportModel makeReport({
  String id = 'r1',
  String category = 'Pothole',
  String description = 'Test description',
  String status = 'pending',
  String? address,
}) {
  return ReportModel(
    id: id,
    category: category,
    description: description,
    latitude: 41.1100,
    longitude: -8.6000,
    address: address,
    status: status,
    createdAt: DateTime(2024, 5, 10),
  );
}

Widget buildScreen({User? user, ReportServiceBase? service}) {
  return MaterialApp(
    home: MyReportsScreen(
      auth: FakeFirebaseAuth(user),
      service: service ?? FakeReportService(),
    ),
  );
}

void main() {
  group('MyReportsScreen', () {
    testWidgets('shows sign-in message when user is null', (tester) async {
      await tester.pumpWidget(buildScreen(user: null));
      await tester.pumpAndSettle();

      expect(
        find.text('You must be signed in to view your reports.'),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator while stream is pending',
        (tester) async {
      final streamController = StreamController<List<ReportModel>>();
      final service = FakeReportService(stream: streamController.stream);

      await tester.pumpWidget(buildScreen(user: FakeUser(), service: service));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      streamController.close();
    });

    testWidgets('shows empty state when reports list is empty', (tester) async {
      await tester.pumpWidget(
        buildScreen(user: FakeUser(), service: FakeReportService(reports: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reports yet.'), findsOneWidget);
      expect(find.text('Tap + to report a problem.'), findsOneWidget);
    });

    testWidgets('shows error state when stream emits an error', (tester) async {
      final streamController = StreamController<List<ReportModel>>();
      final service = FakeReportService(stream: streamController.stream);

      await tester.pumpWidget(buildScreen(user: FakeUser(), service: service));
      await tester.pump();

      streamController.addError(Exception('Load failed'));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Failed to load reports'), findsOneWidget);

      streamController.close();
    });

    testWidgets('shows report cards for each report in the list',
        (tester) async {
      final reports = [
        makeReport(id: 'r1', category: 'Pothole', description: 'Big hole'),
        makeReport(id: 'r2', category: 'Trash', description: 'Garbage pile'),
      ];

      await tester.pumpWidget(
        buildScreen(
          user: FakeUser(),
          service: FakeReportService(reports: reports),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pothole'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);
      expect(find.text('Big hole'), findsOneWidget);
      expect(find.text('Garbage pile'), findsOneWidget);
    });

    testWidgets('shows correct status labels for each status', (tester) async {
      final reports = [
        makeReport(id: 'r1', status: 'pending'),
        makeReport(id: 'r2', status: 'in_progress'),
        makeReport(id: 'r3', status: 'resolved'),
      ];

      await tester.pumpWidget(
        buildScreen(
          user: FakeUser(),
          service: FakeReportService(reports: reports),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
    });

    testWidgets('shows address when available', (tester) async {
      final report = makeReport(address: 'Rua das Flores, Lisboa');

      await tester.pumpWidget(
        buildScreen(
          user: FakeUser(),
          service: FakeReportService(reports: [report]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rua das Flores, Lisboa'), findsOneWidget);
    });

    testWidgets('shows coordinates when address is null', (tester) async {
      final report = makeReport(); // no address

      await tester.pumpWidget(
        buildScreen(
          user: FakeUser(),
          service: FakeReportService(reports: [report]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('41.1100'), findsOneWidget);
    });

    testWidgets('shows add button in the app bar', (tester) async {
      await tester.pumpWidget(buildScreen(user: FakeUser()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows delete confirmation dialog when delete is tapped',
        (tester) async {
      final report = makeReport();

      await tester.pumpWidget(
        buildScreen(
          user: FakeUser(),
          service: FakeReportService(reports: [report]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Report'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('does not delete when Cancel is pressed', (tester) async {
      final service = FakeReportService(reports: [makeReport()]);

      await tester.pumpWidget(buildScreen(user: FakeUser(), service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.deleteWasCalled, isFalse);
    });

    testWidgets('calls deleteReport when Delete is confirmed', (tester) async {
      final service = FakeReportService(reports: [makeReport()]);

      await tester.pumpWidget(buildScreen(user: FakeUser(), service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(service.deleteWasCalled, isTrue);
    });

    testWidgets('shows success snackbar after confirmed delete', (tester) async {
      final service = FakeReportService(reports: [makeReport()]);

      await tester.pumpWidget(buildScreen(user: FakeUser(), service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Report deleted.'), findsOneWidget);
    });

    testWidgets('shows error snackbar when delete fails', (tester) async {
      final service = FakeReportService(reports: [makeReport()]);
      service.deleteShouldThrow = true;

      await tester.pumpWidget(buildScreen(user: FakeUser(), service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Failed to delete report.'), findsOneWidget);
    });

    testWidgets('shows bottom sheet with report details when card is tapped',
        (tester) async {
      final report = makeReport(
        category: 'Streetlight',
        description: 'Light is off',
        address: 'Rua X',
      );

      await tester.pumpWidget(
        buildScreen(
          user: FakeUser(),
          service: FakeReportService(reports: [report]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Streetlight'));
      await tester.pumpAndSettle();

      // 'Description' and 'Location' are labels unique to the bottom sheet
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('shows "My Reports" as appbar title', (tester) async {
      await tester.pumpWidget(buildScreen(user: FakeUser()));
      await tester.pumpAndSettle();

      expect(find.text('My Reports'), findsOneWidget);
    });
  });
}
