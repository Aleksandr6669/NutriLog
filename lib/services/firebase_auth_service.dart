import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_bootstrap_service.dart';

class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  Future<UserCredential> signInWithGoogle() async {
    await FirebaseBootstrapService.ensureInitialized();

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign_in_canceled',
        message: 'Google sign in canceled by user.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await _auth.signOut();
  }
}
