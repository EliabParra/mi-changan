// auth_repository.dart
//
// Data-layer boundary for authentication operations (AD-H2-4).
//
// Design decisions:
//   - [AuthClient] is a thin abstract interface over the GoTrueClient surface
//     we actually use. This lets tests supply a FakeAuthClient without
//     initialising the full Supabase SDK.
//   - [SupabaseAuthAdapter] adapts the real [GoTrueClient] to [AuthClient].
//   - [AuthRepository] depends only on [AuthClient] — never on SupabaseClient.
//   - [onAuthStateChange] maps raw [AuthChangeEvent]s to domain [AuthStatus]
//     values so the domain layer has no SDK dependency.

import 'package:mi_changan/features/auth/domain/auth_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState, GoTrueClient;

// ── Abstract interface ─────────────────────────────────────────────────────

/// Minimal surface of GoTrueClient that [AuthRepository] depends on.
/// Implemented by [SupabaseAuthAdapter] in production and by fakes in tests.
abstract class AuthClient {
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signInWithOtp({
    required String email,
    String? redirectTo,
  });

  Future<void> signUp({
    required String email,
    required String password,
    String? redirectTo,
  });

  Future<void> signOut();

  Stream<AuthState> get onAuthStateChange;
}

// ── Supabase adapter ───────────────────────────────────────────────────────

/// Adapts the real [GoTrueClient] to [AuthClient].
///
/// This is the only place we touch the Supabase SDK in the data layer.
class SupabaseAuthAdapter implements AuthClient {
  const SupabaseAuthAdapter(this._auth);

  final GoTrueClient _auth;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signInWithOtp({
    required String email,
    String? redirectTo,
  }) async {
    await _auth.signInWithOtp(email: email, emailRedirectTo: redirectTo);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? redirectTo,
  }) async {
    await _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectTo,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;
}

// ── Repository ─────────────────────────────────────────────────────────────

/// SSOT for authentication operations in the data layer.
///
/// Wraps [AuthClient] and exposes domain-typed outputs:
///   - Methods delegate directly to the underlying auth client.
///   - [onAuthStateChange] converts raw SDK events to [AuthStatus] values.
class AuthRepository {
  const AuthRepository(this._client);

  final AuthClient _client;

  /// Authenticate with email and password.
  ///
  /// Throws on invalid credentials or network errors.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _client.signInWithPassword(email: email, password: password);

  /// Send a magic link OTP email.
  ///
  /// On success, the user receives an email with a deep-link that completes
  /// authentication via [onAuthStateChange] when the link is opened.
  ///
  /// Throws if the email cannot be found or the request fails.
  Future<void> signInWithOtp({
    required String email,
    String? redirectTo,
  }) =>
      _client.signInWithOtp(email: email, redirectTo: redirectTo);

  /// Register a new user with email and password.
  ///
  /// On success, Supabase fires a [AuthChangeEvent.signedIn] event which
  /// the notifier's stream listener converts to [AuthStatus.authenticated].
  ///
  /// Throws if the email is already registered or the password is too weak.
  Future<void> signUp({
    required String email,
    required String password,
    String? redirectTo,
  }) =>
      _client.signUp(
        email: email,
        password: password,
        redirectTo: redirectTo,
      );

  /// Sign the current user out and invalidate the local session.
  Future<void> signOut() => _client.signOut();

  /// Stream of domain [AuthStatus] values mapped from raw SDK auth events.
  ///
  /// Mapping rules:
  ///   - [AuthChangeEvent.signedIn] → [AuthStatus.authenticated]
  ///   - [AuthChangeEvent.tokenRefreshed] → [AuthStatus.authenticated]
  ///   - [AuthChangeEvent.signedOut] → [AuthStatus.unauthenticated]
  ///   - [AuthChangeEvent.initialSession] with a non-null session
  ///     → [AuthStatus.authenticated]
  ///   - All other events (including initialSession with null session)
  ///     → [AuthStatus.unauthenticated]
  Stream<AuthStatus> get onAuthStateChange =>
      _client.onAuthStateChange.map(_mapEvent);

  static AuthStatus _mapEvent(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        return AuthStatus.authenticated;
      case AuthChangeEvent.initialSession:
        // initialSession fires on startup — authenticated only when a session
        // was restored from local storage (session != null).
        return state.session != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      default:
        return AuthStatus.unauthenticated;
    }
  }
}
