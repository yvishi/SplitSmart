import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Handles Google Sign-In — different implementation for web vs Android.
///
/// Web:     Uses Firebase's native `signInWithPopup(GoogleAuthProvider())`
///          — no `google_sign_in` package needed. No gapi.client required.
///          The popup is handled by Firebase JS SDK internally.
///
/// Android: Uses `google_sign_in` package → gets idToken → Firebase credential.
class GoogleAuthService {
  static final _auth = FirebaseAuth.instance;

  // Android only — not used on web
  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Signs in with Google. Returns the signed-in Firebase [User].
  /// Throws [GoogleSignInCancelledException] if user cancels.
  static Future<User> signIn() async {
    if (kIsWeb) {
      return _signInWeb();
    } else {
      return _signInAndroid();
    }
  }

  // ── Web: Firebase signInWithPopup ────────────────────────────────────────
  // Firebase JS SDK handles the entire OAuth popup flow natively.
  // No gapi.client library needed. No google_sign_in package on web.
  // The "OAuth token not passed to gapi.client" GSI log is harmless —
  // Firebase doesn't use gapi.client at all.
  static Future<User> _signInWeb() async {
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');

      final userCredential = await _auth.signInWithPopup(provider);
      final user = userCredential.user;
      if (user == null) throw const GoogleSignInCancelledException();
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        throw const GoogleSignInCancelledException();
      }
      rethrow;
    }
  }

  // ── Android: google_sign_in → Firebase credential ────────────────────────
  static Future<User> _signInAndroid() async {
    final googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) throw const GoogleSignInCancelledException();

    final googleAuth = await googleAccount.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) throw const GoogleSignInCancelledException();
    return user;
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) await _googleSignIn.signOut();
  }
}

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
  @override
  String toString() => 'Google Sign-In was cancelled.';
}
