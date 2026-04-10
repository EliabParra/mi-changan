// auth_notifier_test.dart
//
// TDD Batch B — Task 3.1 RED
// Unit tests for AuthNotifier state transitions:
//   - build() starts with AsyncLoading then resolves to authenticated/unauthenticated
//   - login() transitions to AsyncData(authenticated) on success
//   - login() transitions to AsyncError on failure
//   - sendMagicLink() stays unauthenticated (waiting for deep link)
//   - logout() transitions to AsyncData(unauthenticated)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;
import 'package:mi_changan/features/auth/data/auth_repository.dart';
import 'package:mi_changan/features/auth/data/auth_providers.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';

// ── Controllable fake AuthRepository ─────────────────────────────────────
// Wraps a FakeAuthClient so we control exactly what the notifier "sees".

class FakeAuthClientForNotifier implements AuthClient {
  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastOtpEmail;
  int signOutCallCount = 0;

  Exception? signInError;
  Exception? otpError;

  final _controller = StreamController<AuthState>.broadcast();

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (signInError != null) throw signInError!;
    // Emit signedIn event after successful login
    _controller.add(const AuthState(AuthChangeEvent.signedIn, null));
  }

  @override
  Future<void> signInWithOtp({
    required String email,
    String? redirectTo,
  }) async {
    lastOtpEmail = email;
    if (otpError != null) throw otpError!;
    // Does NOT emit signedIn — user must click deep link
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  void emitAuthEvent(AuthChangeEvent event) {
    _controller.add(AuthState(event, null));
  }

  void close() => _controller.close();
}

/// Creates a [ProviderContainer] with [authRepositoryProvider] overridden
/// by an [AuthRepository] wrapping [fakeClient].
ProviderContainer makeContainer(FakeAuthClientForNotifier fakeClient) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(AuthRepository(fakeClient)),
    ],
  );
}

void main() {
  late FakeAuthClientForNotifier fakeClient;
  late ProviderContainer container;

  setUp(() {
    fakeClient = FakeAuthClientForNotifier();
  });

  tearDown(() {
    container.dispose();
    fakeClient.close();
  });

  // ── build() — initial state ────────────────────────────────────────────

  group('build() initial state', () {
    test('resolves to unauthenticated when stream emits initialSession with no session',
        () async {
      container = makeContainer(fakeClient);

      // Trigger build by reading the notifier
      final sub = container.listen(
        authNotifierProvider,
        (_, __) {},
        fireImmediately: true,
      );

      // Emit initialSession (no session = not logged in)
      fakeClient.emitAuthEvent(AuthChangeEvent.initialSession);
      // Allow stream → Completer → Future → Riverpod state update to settle
      await Future.delayed(Duration.zero);

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<AuthStatus>>());
      expect(state.value, AuthStatus.unauthenticated);

      sub.close();
    });

    test('resolves to authenticated when signedIn event arrives on startup',
        () async {
      container = makeContainer(fakeClient);

      final sub = container.listen(
        authNotifierProvider,
        (_, __) {},
        fireImmediately: true,
      );

      // Simulate app startup with existing session via signedIn
      fakeClient.emitAuthEvent(AuthChangeEvent.signedIn);
      await Future.delayed(Duration.zero);

      final state = container.read(authNotifierProvider);
      expect(state.value, AuthStatus.authenticated);

      sub.close();
    });
  });

  // ── login() ────────────────────────────────────────────────────────────

  group('login()', () {
    test('transitions to AsyncData(authenticated) on successful login',
        () async {
      container = makeContainer(fakeClient);

      // Activate the notifier
      container.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      // Act — login triggers signedIn event internally
      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(email: 'user@example.com', password: 'pass123');
      await Future.delayed(Duration.zero);

      // Assert — state reflects authenticated
      final state = container.read(authNotifierProvider);
      expect(state.value, AuthStatus.authenticated);
    });

    test('transitions to AsyncError on login failure', () async {
      container = makeContainer(fakeClient);
      fakeClient.signInError = Exception('invalid credentials');

      container.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(email: 'bad@example.com', password: 'wrong');
      await Future.delayed(Duration.zero);

      // Assert — state is an error (not a crash)
      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncError<AuthStatus>>());
    });
  });

  // ── sendMagicLink() ────────────────────────────────────────────────────

  group('sendMagicLink()', () {
    test('stays unauthenticated after magic link sent (no stream event)', () async {
      container = makeContainer(fakeClient);

      container.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      // Set baseline: emit unauthenticated first
      fakeClient.emitAuthEvent(AuthChangeEvent.initialSession);
      await Future.delayed(Duration.zero);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.sendMagicLink(email: 'user@example.com');
      await Future.delayed(Duration.zero);

      // Assert — no signedIn was emitted; state remains unauthenticated
      final state = container.read(authNotifierProvider);
      expect(state.value, AuthStatus.unauthenticated);
    });

    test('sendMagicLink error transitions to AsyncError', () async {
      container = makeContainer(fakeClient);
      fakeClient.otpError = Exception('email not found');

      container.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.sendMagicLink(email: 'nobody@example.com');
      await Future.delayed(Duration.zero);

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncError<AuthStatus>>());
    });
  });

  // ── logout() ──────────────────────────────────────────────────────────

  group('logout()', () {
    test('transitions to AsyncData(unauthenticated) after logout', () async {
      container = makeContainer(fakeClient);

      container.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      // First authenticate
      fakeClient.emitAuthEvent(AuthChangeEvent.signedIn);
      await Future.delayed(Duration.zero);
      expect(container.read(authNotifierProvider).value, AuthStatus.authenticated);

      // Act — logout triggers signedOut event internally
      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.logout();
      await Future.delayed(Duration.zero);

      // Assert — back to unauthenticated
      final state = container.read(authNotifierProvider);
      expect(state.value, AuthStatus.unauthenticated);
    });
  });
}
