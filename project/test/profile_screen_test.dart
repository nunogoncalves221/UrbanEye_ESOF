import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/auth/edit_profile_screen.dart';
import 'package:project/features/auth/profile_screen.dart';

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;

  FakeFirebaseAuth(this._user);

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

Widget buildProfilePage({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
}) {
  return MaterialApp(
    home: ProfileScreen(auth: auth, firestore: firestore),
  );
}

void main() {
  testWidgets('shows profile data from Firestore', (tester) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildProfilePage(
        auth: FakeFirebaseAuth(FakeUser()),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Hello, Diogo'), findsOneWidget);
    expect(find.text('diogo123'), findsOneWidget);
    expect(find.text('21-05-2004'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
  });

  testWidgets('shows Edit profile button', (tester) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildProfilePage(
        auth: FakeFirebaseAuth(FakeUser()),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
  });

  testWidgets('navigates to EditProfileScreen when Edit profile is tapped', (
    tester,
  ) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildProfilePage(
        auth: FakeFirebaseAuth(FakeUser()),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('shows Not logged in when user is null', (tester) async {
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(
      buildProfilePage(auth: FakeFirebaseAuth(null), firestore: firestore),
    );

    await tester.pumpAndSettle();

    expect(find.text('Not logged in'), findsOneWidget);
  });
}
