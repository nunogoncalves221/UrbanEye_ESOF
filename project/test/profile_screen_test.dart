import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/auth/profile_screen.dart';
import 'package:project/features/main_screen.dart';
import 'package:project/features/report/my_reports_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

// instantiate FakeFirebaseAuth
class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;
  bool signOutCalled = false;
  FakeFirebaseAuth(this._user);

  @override
  Stream<User?> authStateChanges() => Stream.value(_user);

  @override
  User? get currentUser => _user;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

// instantiate FakeUser
class FakeUser extends Fake implements User {
  @override
  String get uid => '123';

  @override
  String get email => 'test@example.com';
}

// instantiate FakeReportService
class FakeReportService extends ReportServiceBase {
  @override
  Stream<List<ReportModel>> watchReportsByUser(String uid) {
    return Stream.value([]);
  }

  @override
  Future<void> deleteReport(ReportModel report) async {}

  @override
  Future<void> submitReport(ReportModel report, {File? photo}) async {}
}

// instantiate buildProfilePage helper
Widget buildProfilePage(FirebaseAuth auth, {ReportServiceBase? service}) {
  return MaterialApp(
    home: ProfileScreen(auth: auth, service: service ?? FakeReportService()),
  );
}

void main() {
  // instantiate user
  final user = FakeUser();

  // show branding
  testWidgets('shows UrbanEye branding', (tester) async {
    await tester.pumpWidget(buildProfilePage(FakeFirebaseAuth(user)));
    await tester.pump();
    expect(find.text('UrbanEye'), findsOneWidget);
  });

  // show greeting with user email
  testWidgets('shows greeting with user email', (tester) async {
    await tester.pumpWidget(buildProfilePage(FakeFirebaseAuth(user)));
    await tester.pump();
    expect(find.text('Hello, test@example.com'), findsOneWidget);
  });

  // show My Reports / Report a problem / Sign out
  testWidgets('shows My Reports / Report a problem / Sign out', (
    tester,
  ) async {
    await tester.pumpWidget(buildProfilePage(FakeFirebaseAuth(user)));
    await tester.pump();
    expect(find.text('My Reports'), findsOneWidget);
    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  // navigate to MyReportsScreen when My Reports is tapped
  testWidgets('navigates to MyReportsScreen when My Reports is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(buildProfilePage(FakeFirebaseAuth(user)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Reports'));
    await tester.pumpAndSettle();
    expect(find.byType(MyReportsScreen), findsOneWidget);
  });

  // navigate to MainScreen when Report a problem is tapped
  testWidgets('navigates to MainScreen when Report a problem is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(buildProfilePage(FakeFirebaseAuth(user)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report a problem'));
    await tester.pumpAndSettle();
    expect(find.byType(MainScreen), findsOneWidget);
  });

  // call signOut when Sign out is tapped
  testWidgets('calls signOut when Sign out is tapped', (tester) async {
    final fakeAuth = FakeFirebaseAuth(user);
    await tester.pumpWidget(buildProfilePage(fakeAuth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(fakeAuth.signOutCalled, isTrue);
  });

  // navigate to MainScreen after sign out
  testWidgets('navigates to MainScreen after sign out', (tester) async {
    final fakeAuth = FakeFirebaseAuth(user);
    await tester.pumpWidget(buildProfilePage(fakeAuth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(MainScreen), findsOneWidget);
  });
}