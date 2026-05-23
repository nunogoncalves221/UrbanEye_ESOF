import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/auth/edit_profile_screen.dart';

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;

  FakeFirebaseAuth(this._user);

  @override
  User? get currentUser => _user;
}

class FakeUser extends Fake implements User {
  String displayNameValue = '';

  @override
  String get uid => '123';

  @override
  String get email => 'test@example.com';

  @override
  Future<void> updateDisplayName(String? displayName) async {
    displayNameValue = displayName ?? '';
  }
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

Widget buildEditProfilePage({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
}) {
  return MaterialApp(
    home: EditProfileScreen(auth: auth, firestore: firestore),
  );
}

void main() {
  testWidgets('loads profile data into text fields', (tester) async {
    final firestore = await createFirestore();

    await tester.pumpWidget(
      buildEditProfilePage(
        auth: FakeFirebaseAuth(FakeUser()),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Diogo'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'diogo123'), findsOneWidget);
    expect(find.widgetWithText(TextField, '21-05-2004'), findsOneWidget);
  });

  testWidgets('updates profile data in Firestore', (tester) async {
    final firestore = await createFirestore();
    final fakeUser = FakeUser();

    await tester.pumpWidget(
      buildEditProfilePage(
        auth: FakeFirebaseAuth(fakeUser),
        firestore: firestore,
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Diogo'), 'Joao');
    await tester.enterText(
      find.widgetWithText(TextField, 'diogo123'),
      'joao123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '21-05-2004'),
      '10-02-2003',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final doc = await firestore.collection('users').doc('123').get();
    final data = doc.data()!;

    expect(data['name'], 'Joao');
    expect(data['username'], 'joao123');

    final birthDate = data['birthDate'] as Timestamp;

    expect(birthDate.toDate().day, 10);
    expect(birthDate.toDate().month, 2);
    expect(birthDate.toDate().year, 2003);

    expect(fakeUser.displayNameValue, 'Joao');
  });
}
