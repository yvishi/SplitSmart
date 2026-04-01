import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/user.dart';
import 'user_repository.dart';

// ─── Auth State ───────────────────────────────────────────────────────────────

/// Sealed hierarchy so the router can pattern-match without ambiguity.
sealed class AuthState {
  const AuthState();
}

/// Firebase SDK initialising or stream hasn't emitted yet.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No Firebase user — show /login.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Firebase user exists but no Firestore profile yet — show /complete-profile.
class AuthNeedsProfile extends AuthState {
  const AuthNeedsProfile({required this.uid, required this.phone});
  final String uid;
  final String phone;
}

/// Fully authenticated with a Firestore profile — show /home.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.profile});
  final AppUser profile;
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<User?>? _sub;

  @override
  AuthState build() {
    // Listen to Firebase Auth state changes
    _sub?.cancel();
    _sub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    // Cleanup when provider is disposed
    ref.onDispose(() => _sub?.cancel());
    return const AuthLoading();
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      state = const AuthUnauthenticated();
      return;
    }

    // User is authenticated — check if their Firestore profile exists
    try {
      final profile = await UserRepository.fetchCurrentUser();
      if (profile == null) {
        // New user: authed but no Firestore doc yet → collect profile
        state = AuthNeedsProfile(
          uid: firebaseUser.uid,
          phone: firebaseUser.phoneNumber ??
              firebaseUser.email ??
              firebaseUser.displayName ??
              '',
        );
      } else {
        state = AuthAuthenticated(profile: profile);
      }
    } catch (e) {
      // Firestore unreachable or security rules blocked the read.
      // Do NOT log out — the user IS authenticated.
      // Treat as new user so they can complete their profile.
      // Once they save, Firestore write will reveal the real problem.
      state = AuthNeedsProfile(
        uid: firebaseUser.uid,
        phone: firebaseUser.phoneNumber ??
            firebaseUser.email ??
            firebaseUser.displayName ??
            '',
      );
    }
  }

  // ── Called after first profile creation ──────────────────────────────────
  Future<void> profileCreated() async {
    final profile = await UserRepository.fetchCurrentUser();
    if (profile != null) {
      state = AuthAuthenticated(profile: profile);
    }
  }

  // ── Called from profile screen after edits ────────────────────────────────
  Future<void> refreshProfile() async {
    final profile = await UserRepository.fetchCurrentUser();
    if (profile != null) {
      state = AuthAuthenticated(profile: profile);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    // authStateChanges stream will fire → sets AuthUnauthenticated
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Delete Firestore profile first
    await UserRepository.deleteProfile(user.uid);
    // Then delete Firebase Auth user
    await user.delete();
    // authStateChanges stream fires → AuthUnauthenticated
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());

/// Convenience read-only provider — used by the router redirect hook.
final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authNotifierProvider);
});
