import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/auth/auth_screen.dart';
import 'package:project/features/auth/profile_screen.dart';
import 'package:project/features/main_screen.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

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

  @override
  String get email => 'test@example.com';

  @override
  Future<void> updateDisplayName(String? displayName) async {}
}

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

Future<FakeFirebaseFirestore> createFirestore() async {
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('users').doc('123').set({
    'uid': '123',
    'email': 'test@example.com',
    'name': 'Diogo',
    'username': 'diogo123',
    'birthDate': Timestamp.fromDate(DateTime(2004, 5, 21)),
  });

  return firestore;
}

Widget buildMainScreen({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
}) {
  return MaterialApp(
    home: MainScreen(
      auth: auth,
      firestore: firestore,
      reportService: FakeReportService(),
    ),
  );
}

void main() {
  testWidgets('shows Login / Register when user is not logged in', (
    tester,
  ) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildMainScreen(
        auth: FakeFirebaseAuth(null),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Login / Register'), findsOneWidget);
  });

  testWidgets('shows Profile when user is logged in', (tester) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildMainScreen(
        auth: FakeFirebaseAuth(FakeUser()),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('navigates to ProfileScreen when Profile is clicked', (
    tester,
  ) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildMainScreen(
        auth: FakeFirebaseAuth(FakeUser()),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('navigates to AuthScreen when Login / Register is clicked', (
    tester,
  ) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildMainScreen(
        auth: FakeFirebaseAuth(null),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Login / Register'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('shows Report a Problem button', (tester) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildMainScreen(
        auth: FakeFirebaseAuth(FakeUser()),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Report a Problem'), findsOneWidget);
  });
}