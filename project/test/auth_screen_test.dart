import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/auth/auth_screen.dart';
import 'package:project/features/auth/login_screen.dart';
import 'package:project/features/auth/register_screen.dart';
import 'package:project/features/main_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

// instantiate FakeFirebaseAuth
class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth();

  @override
  Stream<User?> authStateChanges() => Stream.value(null);

  @override
  User? get currentUser => null;
}

// instantiate FakeReportService
class FakeReportService extends ReportServiceBase {
  @override
  Future<void> confirmReportByAuthority(String reportId) async {
    return;
  }

  @override
  Stream<List<ReportModel>> watchReportsByUser(String uid) {
    return Stream.value([]);
  }

  @override
  Future<void> deleteReport(ReportModel report) async {}

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

// instantiate buildAuthPage helper
Widget buildAuthPage(FirebaseAuth auth, {ReportServiceBase? service}) {
  return MaterialApp(
    home: AuthScreen(auth: auth, service: service ?? FakeReportService()),
  );
}

void main() {
  // show branding
  testWidgets('shows UrbanEye branding', (tester) async {
    await tester.pumpWidget(buildAuthPage(FakeFirebaseAuth()));
    await tester.pump();
    expect(find.text('UrbanEye'), findsOneWidget);
  });

  // show buttons
  testWidgets('shows Sign in / Create account / Sign in as guest', (
    tester,
  ) async {
    await tester.pumpWidget(buildAuthPage(FakeFirebaseAuth()));
    await tester.pump();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in as guest'), findsOneWidget);
  });

  // navigate to LoginScreen when Sign in is tapped
  testWidgets('navigates to LoginScreen when Sign in is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(buildAuthPage(FakeFirebaseAuth()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  // navigate to RegisterScreen when Create account is tapped
  testWidgets('navigates to RegisterScreen when Create account is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(buildAuthPage(FakeFirebaseAuth()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  // navigate to MainScreen when Sign in as guest is tapped
  testWidgets('navigates to MainScreen when Sign in as guest is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(buildAuthPage(FakeFirebaseAuth()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in as guest'));
    await tester.pumpAndSettle();
    expect(find.byType(MainScreen), findsOneWidget);
  });
}
