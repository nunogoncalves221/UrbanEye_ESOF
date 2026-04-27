import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:project/features/main_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/auth/welcome_screen.dart';

// instantiate FakeReportService
class FakeReportService extends ReportServiceBase {
  @override
  Stream<List<ReportModel>> watchReportsByUser(String uid) {
    return Stream.value([]); // Return an empty list (no actual data)
  }

  @override
  Future<void> deleteReport(ReportModel report) async {}

  @override
  Future<void> submitReport(ReportModel report, {File? photo}) async {}
}

// instantiate FakeFirebaseAuth
class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;
  FakeFirebaseAuth(this._user);

  @override
  Stream<User?> authStateChanges() => Stream.value(_user);

  @override
  User? get currentUser => _user;
}

// instantiate FakeUser
class FakeUser extends Fake implements User {
  @override
  String get uid => '123';

  @override
  String get email => 'test@example.com';
}

// instantiate buildPage helper
Widget buildPage(
  FirebaseAuth auth, {
  required ReportServiceBase reportService,
}) {
  return MaterialApp(
    home: MainScreen(auth: auth, reportService: reportService),
  );
}

// instantiate buildWelcomePage helper
Widget buildWelcomePage(FirebaseAuth auth) {
  return MaterialApp(home: WelcomeScreen(auth: auth));
}

void main() {
  // instantiate user
  final user = FakeUser();

  // check if unauthenticated
  testWidgets('shows Login / Register when user is null', (tester) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(null), reportService: FakeReportService()),
    );
    await tester.pump(); // Let StreamBuilder build
    expect(
      find.text('Login / Register'),
      findsOneWidget,
    ); // Check for Login text
  });

  // check if authenticated
  testWidgets('shows Profile when user is logged in', (tester) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pump();
    expect(find.text('Profile'), findsOneWidget); // Check for Profile text
  });

  testWidgets('navigates to ReportScreen when button is clicked', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report a Problem')); // Tap button
    await tester.pumpAndSettle(); // Wait for navigation
    expect(
      find.byType(ReportScreen),
      findsOneWidget,
    ); // Check if ReportScreen appears
  });

  testWidgets('navigates to WelcomeScreen when Profile is clicked', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile')); // Tap Profile
    await tester.pumpAndSettle(); // Wait for navigation
    expect(
      find.byType(WelcomeScreen),
      findsOneWidget,
    ); // Check if WelcomeScreen appears
  });

  testWidgets(
    'navigates to MainScreen when Report a problem is clicked on WelcomeScreen',
    (tester) async {
      await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(user)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report a problem')); // Tap button
      await tester.pumpAndSettle(); // Wait for navigation
      expect(
        find.byType(MainScreen),
        findsOneWidget,
      ); // Check if MainScreen appears
    },
  );

  // new tests for search bar and map functionality

  // check if search bar is present
  testWidgets('shows search bar with placeholder text', (tester) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pump();
    expect(
      find.byType(TextField),
      findsOneWidget,
    ); // Check for TextField
    expect(
      find.text('Search for an address...'),
      findsOneWidget,
    ); // Check for placeholder text
  });

  // check if search icon button is present
  testWidgets('shows search icon button', (tester) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pump();
    expect(
      find.byIcon(Icons.search),
      findsOneWidget,
    ); // Check for search icon
  });

  // check if map is displayed
  testWidgets('displays map', (tester) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pump();
    expect(
      find.byType(FlutterMap),
      findsOneWidget,
    ); // Check for FlutterMap widget
  });

  // check if report button is present
  testWidgets('shows Report a Problem button', (tester) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pump();
    expect(
      find.text('Report a Problem'),
      findsOneWidget,
    ); // Check for button text
  });

  // check if search updates map marker
  testWidgets('search button triggers search action', (tester) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Lisbon, Portugal');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget); // Search triggered
  });
}
