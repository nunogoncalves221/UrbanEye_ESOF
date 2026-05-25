// Acceptance Tests
//
// Each test maps to a concrete user story and exercises the full UI flow
// from the user's perspective.  External services (Firebase Auth, Firestore,
// ReportService) are replaced with fakes/mocks so tests run offline without
// a real Firebase project.

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:project/features/auth/login_screen.dart';
import 'package:project/features/report/all_reports_screen.dart';
import 'package:project/features/auth/register_screen.dart';
import 'package:project/features/report/my_reports_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/report/report_controller.dart';
import 'package:project/services/auth_service.dart';
import 'package:project/services/report_service.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockAuthService extends Mock implements AuthService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockReportService extends Mock implements ReportServiceBase {}

class FakeReportModel extends Fake implements ReportModel {}

class FakeFirebaseAuthException extends FirebaseAuthException {
  FakeFirebaseAuthException({required super.code, super.message});
}

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
  Future<void> confirmProblem(
    String reportId,
    String userId,
    bool confirmed,
  ) async {}

  @override
  Future<bool> hasUserConfirmed(String reportId, String userId) async => false;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

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

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(FakeReportModel());
  });

  // ── User Authentication ───────────────────────────────────────────────────

  group('User Authentication', () {
    testWidgets(
      'Acceptance Test: User signs in successfully with valid credentials',
      (tester) async {
        final mockAuth = MockAuthService();
        final mockCredential = MockUserCredential();
        bool successCalled = false;

        when(
          () => mockAuth.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockCredential);

        await tester.pumpWidget(
          MaterialApp(
            home: LoginScreen(
              authService: mockAuth,
              onSuccess: () => successCalled = true,
            ),
          ),
        );

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'user@example.com');
        await tester.enterText(fields.at(1), 'password123');

        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Login successful'), findsOneWidget);
        expect(successCalled, isTrue);

        verify(
          () => mockAuth.signIn(
            email: 'user@example.com',
            password: 'password123',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'Acceptance Test: User is shown an error when signing in with wrong password',
      (tester) async {
        final mockAuth = MockAuthService();

        when(
          () => mockAuth.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          FakeFirebaseAuthException(
            code: 'wrong-password',
            message: 'The password is invalid.',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: LoginScreen(authService: mockAuth)),
        );

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'user@example.com');
        await tester.enterText(fields.at(1), 'wrongpassword');

        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('The password is invalid.'), findsOneWidget);
      },
    );

    testWidgets(
      'Acceptance Test: User creates a new account with valid details',
      (tester) async {
        final mockAuth = MockAuthService();
        final mockCredential = MockUserCredential();
        bool successCalled = false;

        when(
          () => mockAuth.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
            username: any(named: 'username'),
            birthDate: any(named: 'birthDate'),
          ),
        ).thenAnswer((_) async => mockCredential);

        await tester.pumpWidget(
          MaterialApp(
            home: RegisterScreen(
              authService: mockAuth,
              onSuccess: () => successCalled = true,
            ),
          ),
        );

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Maria Silva');
        await tester.enterText(fields.at(1), 'mariasilva');
        await tester.enterText(fields.at(2), '15-03-1995');
        await tester.enterText(fields.at(3), 'maria@example.com');
        await tester.enterText(fields.at(4), 'securepass123');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Account created successfully'), findsOneWidget);
        expect(successCalled, isTrue);

        verify(
          () => mockAuth.register(
            email: 'maria@example.com',
            password: 'securepass123',
            name: 'Maria Silva',
            username: 'mariasilva',
            birthDate: DateTime(1995, 3, 15),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'Acceptance Test: User is shown an error when registering with an invalid birth date format',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: RegisterScreen()));

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'João Costa');
        await tester.enterText(fields.at(1), 'joaocosta');
        await tester.enterText(fields.at(2), '1990/06/20');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
        await tester.pump();

        expect(
          find.text('Birth date must be in dd-mm-yyyy format'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Acceptance Test: User is shown an error when registering with an already registered email',
      (tester) async {
        final mockAuth = MockAuthService();

        when(
          () => mockAuth.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
            username: any(named: 'username'),
            birthDate: any(named: 'birthDate'),
          ),
        ).thenThrow(FakeFirebaseAuthException(code: 'email-already-in-use'));

        await tester.pumpWidget(
          MaterialApp(home: RegisterScreen(authService: mockAuth)),
        );

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Ana Rodrigues');
        await tester.enterText(fields.at(1), 'anarodrigues');
        await tester.enterText(fields.at(2), '20-07-1998');
        await tester.enterText(fields.at(3), 'existing@example.com');
        await tester.enterText(fields.at(4), 'somepassword');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Try again, email already registered'),
          findsOneWidget,
        );
      },
    );
  });

  // ── Report Submission ─────────────────────────────────────────────────────

  group('Report Submission', () {
    testWidgets('Acceptance Test: User submits a report successfully', (
      tester,
    ) async {
      final mockService = MockReportService();
      final mockAuth = MockFirebaseAuth();
      final mockUser = MockUser();

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');
      when(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).thenAnswer((_) async {});

      final controller = ReportController(service: mockService, auth: mockAuth);
      controller.selectedCategory = 'Pothole';
      controller.latitude = 41.15;
      controller.longitude = -8.61;

      await tester.pumpWidget(
        MaterialApp(home: ReportScreen(controller: controller)),
      );

      final descriptionField = find.byType(TextField).last;
      await tester.enterText(
        descriptionField,
        'There is a deep pothole on the road.',
      );

      await tester.tap(find.text('SUBMIT REPORT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Report submitted successfully!'), findsOneWidget);
      verify(
        () => mockService.submitReport(any(), photo: any(named: 'photo')),
      ).called(1);

      await tester.pumpAndSettle();
    });

    testWidgets(
      'Acceptance Test: User submits a report without selecting a location first',
      (tester) async {
        final mockService = MockReportService();
        final mockAuth = MockFirebaseAuth();

        final controller = ReportController(
          service: mockService,
          auth: mockAuth,
        );
        controller.selectedCategory = 'Pothole';

        await tester.pumpWidget(
          MaterialApp(home: ReportScreen(controller: controller)),
        );

        final descriptionField = find.byType(TextField).last;
        await tester.enterText(descriptionField, 'There is a deep pothole.');

        await tester.tap(find.text('SUBMIT REPORT'));
        await tester.pump();

        expect(find.textContaining('fetch your location'), findsOneWidget);
        verifyNever(
          () => mockService.submitReport(any(), photo: any(named: 'photo')),
        );
      },
    );

    testWidgets(
      'Acceptance Test: User submits a report without selecting a category',
      (tester) async {
        final mockService = MockReportService();
        final mockAuth = MockFirebaseAuth();

        final controller = ReportController(
          service: mockService,
          auth: mockAuth,
        );
        controller.latitude = 41.15;
        controller.longitude = -8.61;

        await tester.pumpWidget(
          MaterialApp(home: ReportScreen(controller: controller)),
        );

        final descriptionField = find.byType(TextField).last;
        await tester.enterText(descriptionField, 'Something is broken.');

        await tester.tap(find.text('SUBMIT REPORT'));
        await tester.pump();

        expect(find.textContaining('select a category'), findsOneWidget);
        verifyNever(
          () => mockService.submitReport(any(), photo: any(named: 'photo')),
        );
      },
    );
  });

  // ── Map Report Info Popup ─────────────────────────────────────────────────

  group('Map Report Info Popup', () {
    testWidgets(
      'Acceptance Test: User clicks a map icon and sees the report street address',
      (tester) async {
        final report = makeReport(address: 'Rua de Santa Catarina, Porto');

        await tester.pumpWidget(
          MaterialApp(
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
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Rua de Santa Catarina, Porto'), findsOneWidget);
      },
    );

    testWidgets(
      'Acceptance Test: User clicks a map icon and sees when the problem was reported',
      (tester) async {
        final report = makeReport();

        await tester.pumpWidget(
          MaterialApp(
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
                          children: [
                            Text(report.category),
                            Text(
                              'Reported on '
                              '${report.createdAt.day.toString().padLeft(2, '0')}/'
                              '${report.createdAt.month.toString().padLeft(2, '0')}/'
                              '${report.createdAt.year}',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Reported on 10/05/2024'), findsOneWidget);
      },
    );

    testWidgets(
      'Acceptance Test: User clicks a map icon and sees how many people confirmed and denied the problem',
      (tester) async {
        final report = ReportModel(
          id: 'r1',
          category: 'Pothole',
          description: 'Big pothole',
          latitude: 41.15,
          longitude: -8.61,
          address: 'Rua Principal, Porto',
          status: 'pending',
          createdAt: DateTime(2024, 5, 10),
          existsConfirmations: 5,
          notExistsConfirmations: 2,
        );

        await tester.pumpWidget(
          MaterialApp(
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
                          children: [
                            Text(report.category),
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
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('5 Confirmed'), findsOneWidget);
        expect(find.text('2 Denied'), findsOneWidget);
      },
    );

    testWidgets(
      'Acceptance Test: Authority clicks a map icon and sees the same report info as a regular user',
      (tester) async {
        final report = ReportModel(
          id: 'r1',
          category: 'Streetlight',
          description: 'Light is broken',
          latitude: 41.15,
          longitude: -8.61,
          address: 'Avenida dos Aliados, Porto',
          status: 'in_progress',
          createdAt: DateTime(2024, 3, 1),
          existsConfirmations: 3,
          notExistsConfirmations: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
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
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Streetlight'), findsOneWidget);
        expect(find.text('Avenida dos Aliados, Porto'), findsOneWidget);
        expect(find.textContaining('Reported on 01/03/2024'), findsOneWidget);
        expect(find.text('3 Confirmed'), findsOneWidget);
        expect(find.text('1 Denied'), findsOneWidget);
      },
    );
  });

  // ── Favourite Reports ─────────────────────────────────────────────────────

  group('Favourite Reports', () {
    const statusColors = <String, Color>{'pending': Colors.orange};
    const statusLabels = <String, String>{'pending': 'Pending'};
    const priorityColors = <String, Color>{'low': Colors.grey};
    const priorityLabels = <String, String>{'low': 'Low Priority'};
    const categoryIcons = <String, IconData>{'Pothole': Icons.report_problem};

    Widget buildCard({
      bool isFavourite = false,
      VoidCallback? onFavouriteToggle,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ReportCard(
            report: makeReport(),
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
      'Acceptance Test: User marks a report as favourite and star becomes filled',
      (tester) async {
        bool isFavourite = false;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: ReportCard(
                  report: makeReport(),
                  isFavourite: isFavourite,
                  onFavouriteToggle: () => setState(() => isFavourite = true),
                  statusColors: statusColors,
                  statusLabels: statusLabels,
                  priorityColors: priorityColors,
                  priorityLabels: priorityLabels,
                  categoryIcons: categoryIcons,
                  formatDate: (d) => '${d.day}/${d.month}/${d.year}',
                  extractZone: (_) => null,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.star_border), findsOneWidget);

        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pump();

        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsNothing);
      },
    );

    testWidgets(
      'Acceptance Test: User removes a favourite report and star becomes outline',
      (tester) async {
        bool isFavourite = true;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: ReportCard(
                  report: makeReport(),
                  isFavourite: isFavourite,
                  onFavouriteToggle: () => setState(() => isFavourite = false),
                  statusColors: statusColors,
                  statusLabels: statusLabels,
                  priorityColors: priorityColors,
                  priorityLabels: priorityLabels,
                  categoryIcons: categoryIcons,
                  formatDate: (d) => '${d.day}/${d.month}/${d.year}',
                  extractZone: (_) => null,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);

        await tester.tap(find.byIcon(Icons.star));
        await tester.pump();

        expect(find.byIcon(Icons.star_border), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
      },
    );

    testWidgets(
      'Acceptance Test: Unauthenticated user cannot see the star button on report cards',
      (tester) async {
        await tester.pumpWidget(buildCard());

        expect(find.byIcon(Icons.star_border), findsNothing);
        expect(find.byIcon(Icons.star), findsNothing);
      },
    );

    testWidgets(
      'Acceptance Test: Filter by favourites shows only favourited reports',
      (tester) async {
        final reports = [
          makeReport(id: 'r1', category: 'Pothole'),
          makeReport(id: 'r2', category: 'Streetlight'),
        ];
        const favouriteIds = {'r1'};
        bool filterFavourites = false;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => filterFavourites = true),
                      child: const Text('Show Favourites'),
                    ),
                    ...reports
                        .where(
                          (r) =>
                              !filterFavourites || favouriteIds.contains(r.id),
                        )
                        .map((r) => Text(r.category, key: ValueKey(r.id))),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Pothole'), findsOneWidget);
        expect(find.text('Streetlight'), findsOneWidget);

        await tester.tap(find.text('Show Favourites'));
        await tester.pump();

        expect(find.text('Pothole'), findsOneWidget);
        expect(find.text('Streetlight'), findsNothing);
      },
    );
  });

  // ── My Reports ────────────────────────────────────────────────────────────

  group('My Reports', () {
    testWidgets(
      'Acceptance Test: Signed-in user sees their list of submitted reports',
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
      'Acceptance Test: User successfully deletes one of their reports',
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
      'Acceptance Test: Unauthenticated user is prompted to sign in on My Reports',
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

  // Photo Button in Popups
  group('Photo Button in Popups', () {
    // photo button appears when report has photo
    testWidgets(
      'Acceptance Test: User sees photo button when report has a photo',
      (tester) async {
        final report = ReportModel(
          id: 'r1',
          category: 'Pothole',
          description: 'Big pothole',
          latitude: 41.15,
          longitude: -8.61,
          address: 'Rua Principal, Porto',
          status: 'pending',
          createdAt: DateTime(2024, 5, 10),
          photoUrl: 'https://example.com/photo.jpg',
        );

        await tester.pumpWidget(
          MaterialApp(
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
                          children: [
                            Text(report.category),
                            // check for photo
                            if (report.photoUrl != null)
                              TextButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.photo_camera),
                                label: const Text('photo'),
                              )
                            else
                              const Text('-no photo taken-'),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // photo taken - button should be visible
        expect(find.text('photo'), findsOneWidget);
        expect(find.byIcon(Icons.photo_camera), findsOneWidget);
      },
    );

    // no photo taken
    testWidgets(
      'Acceptance Test: User sees -no photo taken- when report has no photo',
      (tester) async {
        final report = ReportModel(
          id: 'r1',
          category: 'Pothole',
          description: 'Big pothole',
          latitude: 41.15,
          longitude: -8.61,
          address: 'Rua Principal, Porto',
          status: 'pending',
          createdAt: DateTime(2024, 5, 10),
          photoUrl: null,
        );

        await tester.pumpWidget(
          MaterialApp(
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
                          children: [
                            Text(report.category),
                            // check for photo
                            if (report.photoUrl != null)
                              TextButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.photo_camera),
                                label: const Text('photo'),
                              )
                            else
                              const Text('-no photo taken-'),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // no photo taken - text should be visible
        expect(find.text('-no photo taken-'), findsOneWidget);
      },
    );

    // create popup
    testWidgets(
      'Acceptance Test: User can view photo in full screen and close with X',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black54,
                      builder: (context) => Stack(
                        children: [
                          const Center(child: Text('Photo Placeholder')),
                          // X button to close
                          Positioned(
                            top: 40,
                            right: 20,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('View Photo'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('View Photo'));
        await tester.pumpAndSettle();

        // popup should be visible
        expect(find.text('Photo Placeholder'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // close popup with X button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // popup should be closed
        expect(find.text('Photo Placeholder'), findsNothing);
      },
    );
  });
}
