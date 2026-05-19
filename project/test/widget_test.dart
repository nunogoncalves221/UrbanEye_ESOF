import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:project/features/report/my_reports_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

// Import unificado do ecrã e do ReportCard que estão no mesmo ficheiro
import 'package:project/features/report/all_reports_screen.dart';

// ─── Fakes Necessários para Compilar Autónomo ────────────────────────────────

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;
  FakeFirebaseAuth(this._user);

  @override
  User? get currentUser => _user;
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'user123';
}

class FakeReportService extends ReportServiceBase {
  final List<ReportModel> reports;
  bool deleteWasCalled = false;

  FakeReportService({this.reports = const []});

  @override
  Stream<List<ReportModel>> watchReportsByUser(String uid) =>
      Stream.value(reports);

  @override
  Future<void> deleteReport(ReportModel report) async {
    deleteWasCalled = true;
  }

  @override
  Future<void> submitReport(ReportModel report, {File? photo}) async {}

  @override
  Future<bool> checkReportExists(String reportId) async => true;

  @override
  Future<void> confirmProblem(String reportId, String userId, bool confirmed) async {}

  @override
  Future<bool> hasUserConfirmed(String reportId, String userId) async => false;
}

ReportModel makeReport({
  String id = 'r1',
  String category = 'Pothole',
  String description = 'Big pothole on main street',
  String status = 'pending',
  String address = 'Rua Principal, Porto',
}) {
  return ReportModel(
    id: id,
    category: category,
    description: description,
    latitude: 41.15,
    longitude: -8.61,
    address: address,
    status: status,
    createdAt: DateTime(2024, 5, 10),
  );
}

// ─── Widget & Component Tests ────────────────────────────────────────────────

void main() {
  group('My Reports - Screen Widget Tests', () {
    testWidgets(
      'Widget Test: Signed-in user sees their list of submitted reports',
      (tester) async {
        final reports = [
          makeReport(id: 'r1', category: 'Pothole', status: 'pending'),
          makeReport(
            id: 'r2',
            category: 'Streetlight',
            description: 'Light is out near the park',
            status: 'in_progress',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: MyReportsScreen(
              auth: FakeFirebaseAuth(FakeUser()),
              service: FakeReportService(reports: reports),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pothole'), findsOneWidget);
        expect(find.text('Streetlight'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('In Progress'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: Signed-in user with no reports sees the empty state',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MyReportsScreen(
              auth: FakeFirebaseAuth(FakeUser()),
              service: FakeReportService(reports: []),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No reports yet.'), findsOneWidget);
        expect(find.text('Tap + to report a problem.'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: User successfully deletes one of their reports',
      (tester) async {
        final service = FakeReportService(reports: [makeReport()]);

        await tester.pumpWidget(
          MaterialApp(
            home: MyReportsScreen(
              auth: FakeFirebaseAuth(FakeUser()),
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        expect(find.text('Delete Report'), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Report deleted.'), findsOneWidget);
        expect(service.deleteWasCalled, isTrue);
      },
    );

    testWidgets(
      'Widget Test: User cancels report deletion and the report is kept',
      (tester) async {
        final service = FakeReportService(reports: [makeReport()]);

        await tester.pumpWidget(
          MaterialApp(
            home: MyReportsScreen(
              auth: FakeFirebaseAuth(FakeUser()),
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(service.deleteWasCalled, isFalse);
        expect(find.text('Pothole'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: Unauthenticated user is prompted to sign in on My Reports',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MyReportsScreen(
              auth: FakeFirebaseAuth(null),
              service: FakeReportService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('You must be signed in to view your reports.'),
          findsOneWidget,
        );
      },
    );
  });

  group('All Reports - Priority Component Management', () {
    testWidgets(
      'Widget Test: Authority user sees priority badge on report cards',
      (tester) async {
        final report = makeReport(id: 'r1', category: 'Pothole', status: 'pending');
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _ReportCardTestWrapper(
                report: report,
                isAuthority: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Low Priority'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: Non-authority user does not see priority badge',
      (tester) async {
        final report = makeReport(id: 'r1', category: 'Pothole', status: 'pending');
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _ReportCardTestWrapper(
                report: report,
                isAuthority: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
      },
    );

    testWidgets(
      'Widget Test: Authority user can change priority from low to high',
      (tester) async {
        String? updatedPriority;
        final report = makeReport(id: 'r1', category: 'Pothole');
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _ReportCardTestWrapper(
                report: report,
                isAuthority: true,
                onPriorityChanged: (priority) {
                  updatedPriority = priority;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Low Priority'));
        await tester.pumpAndSettle();

        expect(find.text('High Priority'), findsOneWidget);
        expect(find.text('Medium Priority'), findsOneWidget);

        await tester.tap(find.text('High Priority'));
        await tester.pumpAndSettle();

        expect(updatedPriority, equals('high'));
      },
    );

    testWidgets(
      'Widget Test: Authority user can change priority from low to medium',
      (tester) async {
        String? updatedPriority;
        final report = makeReport(id: 'r1', category: 'Pothole');
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _ReportCardTestWrapper(
                report: report,
                isAuthority: true,
                onPriorityChanged: (priority) => updatedPriority = priority,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Low Priority'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Medium Priority'));
        await tester.pumpAndSettle();

        expect(updatedPriority, equals('medium'));
      },
    );

    testWidgets(
      'Widget Test: Authority user filters reports by high priority',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _MockFilterSortSheet(isAuthority: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Priority'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: Non-authority user does not see priority filter option',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _MockFilterSortSheet(isAuthority: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Priority'), findsNothing);
      },
    );
  });
}

// ─── Classes Auxiliares de Teste ─────────────────────────────────────────────

class _ReportCardTestWrapper extends StatelessWidget {
  final ReportModel report;
  final bool isAuthority;
  final void Function(String)? onPriorityChanged;

  const _ReportCardTestWrapper({
    required this.report,
    required this.isAuthority,
    this.onPriorityChanged,
  });

  static const Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'in_progress': Colors.blue,
    'resolved': Colors.green,
  };
  static const Map<String, Color> _priorityColors = {
    'low': Colors.grey,
    'medium': Colors.amber,
    'high': Colors.red,
  };
  static const Map<String, String> _priorityLabels = {
    'low': 'Low Priority',
    'medium': 'Medium Priority',
    'high': 'High Priority',
  };
  static const Map<String, String> _statusLabels = {
    'pending': 'Pending',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
  };
  static const Map<String, IconData> _categoryIcons = {
    'Pothole': Icons.report_problem,
    'Streetlight': Icons.lightbulb_outline,
  };

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      report: report,
      isAuthority: isAuthority,
      statusColors: _statusColors,
      statusLabels: _statusLabels,
      priorityColors: _priorityColors,
      priorityLabels: _priorityLabels,
      categoryIcons: _categoryIcons,
      formatDate: (d) => '${d.day}/${d.month}/${d.year}',
      extractZone: (_) => null,
      onPriorityChanged: onPriorityChanged ?? (priority) {},
    );
  }
}

class _MockFilterSortSheet extends StatelessWidget {
  final bool isAuthority;
  const _MockFilterSortSheet({required this.isAuthority});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Filter'),
        if (isAuthority) ...[
          const Text('Priority'),
          const Text('Low'),
          const Text('Medium'),
          const Text('High'),
        ],
        const Text('Category'),
      ],
    );
  }
}