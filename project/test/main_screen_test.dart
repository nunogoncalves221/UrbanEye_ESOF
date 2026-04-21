import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:project/features/main_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/report/my_reports_screen.dart';

// Simple fake service (just a mock of behavior needed for tests)
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

// Simple fake FirebaseAuth
class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;
  FakeFirebaseAuth(this._user);

  @override
  Stream<User?> authStateChanges() => Stream.value(_user);

  @override
  User? get currentUser => _user;
}

class FakeUser extends Fake implements User {
  @override
  String get uid => '123';
}

// Widget builder to inject dependencies
Widget buildPage(
  FirebaseAuth auth, {
  required ReportServiceBase reportService,
}) {
  return MaterialApp(
    home: MainScreen(auth: auth, reportService: reportService),
  );
}

void main() {
  final user = FakeUser(); // Use a simple fake user

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

  testWidgets('navigates to MyReportsScreen when Profile is clicked', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(FakeFirebaseAuth(user), reportService: FakeReportService()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile')); // Tap Profile
    await tester.pumpAndSettle(); // Wait for navigation
    expect(
      find.byType(MyReportsScreen),
      findsOneWidget,
    ); // Check if MyReportsScreen appears
  });
}
