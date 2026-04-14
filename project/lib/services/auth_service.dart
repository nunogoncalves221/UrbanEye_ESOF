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
  }) {
    return firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return firebaseAuth.signOut();
  }

  User? get currentUser => firebaseAuth.currentUser;
}