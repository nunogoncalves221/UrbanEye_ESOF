import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  const AuthService();

  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
    required String username,
    required DateTime birthDate,
  }) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;

    await user.updateDisplayName(name);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'username': username,
          'birthDate': Timestamp.fromDate(birthDate),
          'createdAt': FieldValue.serverTimestamp(),
        });

    return credential;
  }

  Future<void> signOut() {
    return firebaseAuth.signOut();
  }

  User? get currentUser => firebaseAuth.currentUser;
}
