// auth_repository_test.dart
//
// TDD Batch B — Task 2.1 RED
// Unit tests for AuthRepository contract:
//   - signInWithPassword delegates to auth client with correct args
//   - signInWithOtp (magic link) delegates to auth client with correct args
//   - signOut delegates to auth client and is counted correctly
//   - onAuthStateChange maps AuthChangeEvent to AuthStatus stream

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;
import 'package:mi_changan/features/auth/data/auth_repository.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';

// ── Minimal fake for AuthClient ────────────────────────────────────────────
// AuthRepository depends on [AuthClient] — a thin abstract class defined
// in auth_repository.dart that wraps the minimal GoTrueClient surface we use.
// FakeAuthClient implements AuthClient and records calls for assertion.

class FakeAuthClient implements AuthClient {
  // Recorded call args
  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastOtpEmail;
  String? lastOtpRedirectTo;
  int signOutCallCount = 0;

  // Controllable error responses
  Exception? signInError;
  Exception? otpError;
  Exception? signOutError;

  // Stream controller for auth state changes
  final _authStateController = StreamController<AuthState>.broadcast();

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signInWithOtp({
    required String email,
    String? redirectTo,
  }) async {
    lastOtpEmail = email;
    lastOtpRedirectTo = redirectTo;
    if (otpError != null) throw otpError!;
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    // Not tested in this file — implemented to satisfy AuthClient interface.
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    if (signOutError != null) throw signOutError!;
  }

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  void emitAuthEvent(AuthChangeEvent event) {
    _authStateController.add(AuthState(event, null));
  }

  void close() => _authStateController.close();
}

void main() {
  late FakeAuthClient fakeClient;
  late AuthRepository repository;

  setUp(() {
    fakeClient = FakeAuthClient();
    repository = AuthRepository(fakeClient);
  });

  tearDown(() {
    fakeClient.close();
  });

  // ── signInWithPassword ────────────────────────────────────────────────────

  group('signInWithPassword', () {
    test('forwards email and password to auth client', () async {
      // Act
      await repository.signInWithPassword(
        email: 'test@example.com',
        password: 'secret123',
      );

      // Assert — production code RAN and forwarded real values
      expect(fakeClient.lastSignInEmail, 'test@example.com');
      expect(fakeClient.lastSignInPassword, 'secret123');
    });

    test('propagates exception thrown by auth client', () async {
      // Arrange — configure error
      fakeClient.signInError = Exception('invalid credentials');

      // Act & Assert — exception surfaces to caller
      expect(
        () => repository.signInWithPassword(
          email: 'bad@example.com',
          password: 'wrong',
        ),
        throwsException,
      );
    });
  });

  // ── signInWithOtp (magic link) ────────────────────────────────────────────

  group('signInWithOtp', () {
    test('forwards email and redirectTo to auth client', () async {
      // Act
      await repository.signInWithOtp(
        email: 'magic@example.com',
        redirectTo: 'io.michangan.app://login-callback',
      );

      // Assert — correct delegation of BOTH params
      expect(fakeClient.lastOtpEmail, 'magic@example.com');
      expect(
          fakeClient.lastOtpRedirectTo, 'io.michangan.app://login-callback');
    });

    test('propagates exception from auth client during otp request', () async {
      // Arrange
      fakeClient.otpError = Exception('email not found');

      // Act & Assert
      expect(
        () => repository.signInWithOtp(
          email: 'nobody@example.com',
          redirectTo: 'io.michangan.app://login-callback',
        ),
        throwsException,
      );
    });
  });

  // ── signOut ────────────────────────────────────────────────────────────────

  group('signOut', () {
    test('calls signOut on auth client exactly once per invocation', () async {
      // Act
      await repository.signOut();

      // Assert — real call count, not a smoke assertion
      expect(fakeClient.signOutCallCount, 1);
    });

    test('each signOut call increments the call count independently', () async {
      // Triangulate — two separate calls each delegate once
      await repository.signOut();
      await repository.signOut();

      expect(fakeClient.signOutCallCount, 2);
    });
  });

  // ── onAuthStateChange stream mapping ──────────────────────────────────────

  group('onAuthStateChange stream', () {
    test('maps signedIn event to AuthStatus.authenticated', () async {
      // Arrange
      final emitted = <AuthStatus>[];
      final sub = repository.onAuthStateChange.listen(emitted.add);

      // Act — emit real Supabase event type
      fakeClient.emitAuthEvent(AuthChangeEvent.signedIn);
      await Future.microtask(() {});

      // Assert — mapped value is the concrete expected constant
      expect(emitted, [AuthStatus.authenticated]);
      await sub.cancel();
    });

    test('maps signedOut event to AuthStatus.unauthenticated', () async {
      // Arrange
      final emitted = <AuthStatus>[];
      final sub = repository.onAuthStateChange.listen(emitted.add);

      // Act
      fakeClient.emitAuthEvent(AuthChangeEvent.signedOut);
      await Future.microtask(() {});

      // Assert
      expect(emitted, [AuthStatus.unauthenticated]);
      await sub.cancel();
    });

    test('maps tokenRefreshed event to AuthStatus.authenticated', () async {
      // Triangulate — tokenRefreshed is a "still authenticated" signal
      final emitted = <AuthStatus>[];
      final sub = repository.onAuthStateChange.listen(emitted.add);

      fakeClient.emitAuthEvent(AuthChangeEvent.tokenRefreshed);
      await Future.microtask(() {});

      expect(emitted, [AuthStatus.authenticated]);
      await sub.cancel();
    });

    test('maps initialSession with null session to AuthStatus.unauthenticated',
        () async {
      // Triangulate — initialSession + no session → not logged in
      final emitted = <AuthStatus>[];
      final sub = repository.onAuthStateChange.listen(emitted.add);

      fakeClient.emitAuthEvent(AuthChangeEvent.initialSession);
      await Future.microtask(() {});

      // null session = unauthenticated
      expect(emitted, [AuthStatus.unauthenticated]);
      await sub.cancel();
    });
  });
}
