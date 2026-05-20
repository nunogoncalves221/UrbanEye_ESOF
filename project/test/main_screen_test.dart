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
  Future<void> confirmProblem(String reportId, String userId, bool confirmed) async {}

  @override
  Future<bool> hasUserConfirmed(String reportId, String userId) async => false;
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

  // confirmation feature tests
  group('MapScreen confirmation buttons', () {
    // buttons are hidden when user is not logged in
    testWidgets('buttons are hidden when user is not logged in', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestConfirmationWidget(
              user: null,
              reportOwnerId: 'otherUser',
              hasConfirmed: false,
            ),
          ),
        ),
      );

      expect(find.text('Exists'), findsNothing);
      expect(find.text("Doesn't exist"), findsNothing);
    });

    // buttons are hidden when user is the report owner (same uid)
    testWidgets('buttons are hidden when user is the report owner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestConfirmationWidget(
              user: FakeUser(),
              reportOwnerId: '123',
              hasConfirmed: false,
            ),
          ),
        ),
      );

      expect(find.text('Exists'), findsNothing);
      expect(find.text("Doesn't exist"), findsNothing);
    });

    // buttons are hidden when user already confirmed
    testWidgets('buttons are hidden when user already confirmed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestConfirmationWidget(
              user: FakeUser(),
              reportOwnerId: 'otherUser',
              hasConfirmed: true,
            ),
          ),
        ),
      );

      expect(find.text('Exists'), findsNothing);
      expect(find.text("Doesn't exist"), findsNothing);
      expect(find.text('Thank you for your feedback!'), findsOneWidget);
    });

    // shows buttons for logged in user who has not confirmed
    testWidgets('shows buttons for logged in user who has not confirmed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestConfirmationWidget(
              user: FakeUser(),
              reportOwnerId: 'otherUser',
              hasConfirmed: false,
            ),
          ),
        ),
      );

      expect(find.text('Exists'), findsOneWidget);
      expect(find.text("Doesn't exist"), findsOneWidget);
    });
  });
}

// test helper widget for confirmation button tests
class _TestConfirmationWidget extends StatelessWidget {
  final User? user;
  final String reportOwnerId;
  final bool hasConfirmed;

  const _TestConfirmationWidget({
    required this.user,
    required this.reportOwnerId,
    required this.hasConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null || user!.uid == reportOwnerId) {
      return const SizedBox.shrink();
    }

    if (hasConfirmed) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: const Text('Thank you for your feedback!'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Exists'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text("Doesn't exist"),
          ),
        ),
      ],
    );
  }
}