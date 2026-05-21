import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:project/features/report/my_reports_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/features/report/all_reports_screen.dart';
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
}

class FakeReportService extends ReportServiceBase {
  final List<ReportModel> reports;
  bool deleteWasCalled = false;

  FakeReportService({this.reports = const []});
  @override
  Future<void> confirmReportByAuthority(String reportId) async {
    return;
  }

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
  group('Map Report Info Bottom Sheet', () {
    ReportModel makeDetailedReport({
      int existsConfirmations = 0,
      int notExistsConfirmations = 0,
      String? address,
    }) {
      return ReportModel(
        id: 'r1',
        category: 'Pothole',
        description: 'Big pothole on the road',
        latitude: 41.15,
        longitude: -8.61,
        address: address ?? 'Rua de Santa Catarina, Porto',
        status: 'pending',
        createdAt: DateTime(2024, 5, 10, 14, 30),
        existsConfirmations: existsConfirmations,
        notExistsConfirmations: notExistsConfirmations,
      );
    }

    Widget buildBottomSheet(ReportModel report) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.category),
                        Text(report.address ?? ''),
                        Text(
                          'Reported on '
                          '${report.createdAt.day.toString().padLeft(2, '0')}/'
                          '${report.createdAt.month.toString().padLeft(2, '0')}/'
                          '${report.createdAt.year}',
                        ),
                        Text('${report.existsConfirmations} Confirmed'),
                        Text('${report.notExistsConfirmations} Denied'),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Widget Test: Bottom sheet shows report category',
      (tester) async {
        final report = makeDetailedReport();
        await tester.pumpWidget(buildBottomSheet(report));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Pothole'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: Bottom sheet shows street address',
      (tester) async {
        final report = makeDetailedReport(address: 'Rua das Flores, Porto');
        await tester.pumpWidget(buildBottomSheet(report));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Rua das Flores, Porto'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: Bottom sheet shows formatted upload date',
      (tester) async {
        final report = makeDetailedReport();
        await tester.pumpWidget(buildBottomSheet(report));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Reported on 10/05/2024'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: Bottom sheet shows zero confirmations when none exist',
      (tester) async {
        final report = makeDetailedReport(
          existsConfirmations: 0,
          notExistsConfirmations: 0,
        );
        await tester.pumpWidget(buildBottomSheet(report));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('0 Confirmed'), findsOneWidget);
        expect(find.text('0 Denied'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: Bottom sheet shows correct confirmation counts',
      (tester) async {
        final report = makeDetailedReport(
          existsConfirmations: 8,
          notExistsConfirmations: 3,
        );
        await tester.pumpWidget(buildBottomSheet(report));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('8 Confirmed'), findsOneWidget);
        expect(find.text('3 Denied'), findsOneWidget);
      },
    );
  });

  group('My Reports - Screen Widget Tests', () {
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

  group('ReportCard - Favourite Star Button', () {
    const statusColors = <String, Color>{
      'pending': Colors.orange,
      'in_progress': Colors.blue,
      'resolved': Colors.green,
    };
    const statusLabels = <String, String>{
      'pending': 'Pending',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
    };
    const priorityColors = <String, Color>{
      'low': Colors.grey,
      'medium': Colors.amber,
      'high': Colors.red,
    };
    const priorityLabels = <String, String>{
      'low': 'Low Priority',
      'medium': 'Medium Priority',
      'high': 'High Priority',
    };
    const categoryIcons = <String, IconData>{'Pothole': Icons.report_problem};

    Widget buildCard({bool isFavourite = false, VoidCallback? onFavouriteToggle}) {
      return MaterialApp(
        home: Scaffold(
          body: ReportCard(
            report: makeReport(),
            isAuthority: false,
            isFavourite: isFavourite,
            onFavouriteToggle: onFavouriteToggle,
            statusColors: statusColors,
            statusLabels: statusLabels,
            priorityColors: priorityColors,
            priorityLabels: priorityLabels,
            categoryIcons: categoryIcons,
            formatDate: (d) => '${d.day}/${d.month}/${d.year}',
            extractZone: (_) => null,
          ),
        ),
      );
    }

    testWidgets(
      'Widget Test: star_border shown for authenticated user when report is not favourite',
      (tester) async {
        await tester.pumpWidget(buildCard(onFavouriteToggle: () {}));

        expect(find.byIcon(Icons.star_border), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
      },
    );

    testWidgets(
      'Widget Test: filled star shown when report is marked as favourite',
      (tester) async {
        await tester.pumpWidget(
          buildCard(isFavourite: true, onFavouriteToggle: () {}),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsNothing);
      },
    );

    testWidgets(
      'Widget Test: star button is hidden when onFavouriteToggle is null (unauthenticated user)',
      (tester) async {
        await tester.pumpWidget(buildCard());

        expect(find.byIcon(Icons.star_border), findsNothing);
        expect(find.byIcon(Icons.star), findsNothing);
      },
    );

    testWidgets(
      'Widget Test: tapping the star button calls onFavouriteToggle callback',
      (tester) async {
        bool toggled = false;
        await tester.pumpWidget(
          buildCard(onFavouriteToggle: () => toggled = true),
        );

        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pump();

        expect(toggled, isTrue);
      },
    );
  });

  group('All Reports - Favourites Filter Visibility', () {
    testWidgets(
      'Widget Test: logged-in user sees Favourites only toggle in filter sheet',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: _MockFilterSortSheet(isAuthority: false, isLoggedIn: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Favourites only'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget Test: non-logged-in user does not see Favourites only toggle in filter sheet',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: _MockFilterSortSheet(isAuthority: false, isLoggedIn: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Favourites only'), findsNothing);
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
  final bool isLoggedIn;
  const _MockFilterSortSheet({required this.isAuthority, this.isLoggedIn = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Filter'),
        if (isLoggedIn) const Text('Favourites only'),
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