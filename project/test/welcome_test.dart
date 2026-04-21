import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/auth/welcome_screen.dart';
import 'package:project/features/auth/login_screen.dart';
import 'package:project/features/auth/register_screen.dart';
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

// instantiate buildWelcomePage helper
Widget buildWelcomePage(FirebaseAuth auth, {ReportServiceBase? service}) {
  return MaterialApp(
    home: WelcomeScreen(auth: auth, service: service ?? FakeReportService()),
  );
}

void main() {
  // instantiate user
  final user = FakeUser();

  // unauthenticated tests
  group('unauthenticated', () {
    testWidgets('shows Sign in / Create account / Sign in as guest', (tester) async {
      await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(null)));
      await tester.pump();
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Sign in as guest'), findsOneWidget);
    });

    testWidgets('navigates to LoginScreen when Sign in is tapped', (tester) async {
      await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(null)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('navigates to RegisterScreen when Create account is tapped', (tester) async {
      await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(null)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('navigates to MainScreen when Sign in as guest is tapped', (tester) async {
      await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(null)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in as guest'));
      await tester.pumpAndSettle();
      expect(find.byType(MainScreen), findsOneWidget);
    });
  });

  // authenticated tests
  group('authenticated', () {
    testWidgets('shows greeting with user email', (tester) async {
      await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(user)));
      await tester.pump();
      expect(find.text('Hello, test@example.com'), findsOneWidget);
    });

    testWidgets('shows My Reports / Report a problem / Sign out', (tester) async {
      await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(user)));
      await tester.pump();
      expect(find.text('My Reports'), findsOneWidget);
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('navigates to MyReportsScreen when My Reports is tapped', (tester) async {
      await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(user)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Reports'));
      await tester.pumpAndSettle();
      expect(find.byType(MyReportsScreen), findsOneWidget);
    });

    testWidgets(
      'navigates to MainScreen when Report a problem is tapped',
      (tester) async {
        await tester.pumpWidget(buildWelcomePage(FakeFirebaseAuth(user)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report a problem'));
        await tester.pumpAndSettle();
        expect(find.byType(MainScreen), findsOneWidget);
      },
    );

    testWidgets('calls signOut when Sign out is tapped', (tester) async {
      final fakeAuth = FakeFirebaseAuth(user);
      await tester.pumpWidget(buildWelcomePage(fakeAuth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(fakeAuth.signOutCalled, isTrue);
    });
  });
}