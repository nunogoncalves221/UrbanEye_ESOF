import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:project/features/main_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/auth/auth_screen.dart';
import 'package:project/features/auth/profile_screen.dart';

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

// instantiate buildAuthPage helper
Widget buildAuthPage(FirebaseAuth auth) {
  return MaterialApp(
    home: AuthScreen(auth: auth, service: FakeReportService()),
  );
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

  testWidgets('navigates to ProfileScreen when Profile is clicked', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile')); // Tap Profile
    await tester.pumpAndSettle(); // Wait for navigation
    expect(
      find.byType(ProfileScreen),
      findsOneWidget,
    ); // Check if ProfileScreen appears
  });

  // navigate to AuthScreen when Login / Register is clicked
  testWidgets('navigates to AuthScreen when Login / Register is clicked', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(null), reportService: FakeReportService()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login / Register')); // Tap Login / Register
    await tester.pumpAndSettle(); // Wait for navigation
    expect(
      find.byType(AuthScreen),
      findsOneWidget,
    ); // Check if AuthScreen appears
  });

  testWidgets(
    'navigates to MainScreen when Sign in as guest is clicked on AuthScreen',
    (tester) async {
      await tester.pumpWidget(buildAuthPage(FakeFirebaseAuth(user)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in as guest')); // Tap button
      await tester.pumpAndSettle(); // Wait for navigation
      expect(
        find.byType(MainScreen),
        findsOneWidget,
      ); // Check if MainScreen appears
    },
  );
}
