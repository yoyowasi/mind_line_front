import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static Future<UserCredential> login(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, password: password);
  }

  static Future<UserCredential> register(String email, String password) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  static Future<void> logout() => FirebaseAuth.instance.signOut();
}
