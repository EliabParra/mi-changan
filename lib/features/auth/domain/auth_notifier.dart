// auth_notifier.dart
//
// Domain-layer AsyncNotifier for auth state (AD-H2-3).
//
// Design decisions:
//   - Extends [AsyncNotifier<AuthStatus>] (Riverpod v2 pattern).
//   - [build()] subscribes to [AuthRepository.onAuthStateChange] and drives
//     state from the stream. Auth state is always in sync with the Supabase
//     session, including deep link callbacks.
//   - [login()], [sendMagicLink()], [logout()] delegate to the repository
//     and set [AsyncError] if the call fails.
//   - [register()] passes emailRedirectTo for mobile deep-link callback and
//     sets [AuthStatus.pendingEmailConfirmation] when email confirm is ON
//     (detected by no signedIn event fired synchronously after signUp).
//   - Magic link send does NOT change auth status — the stream fires when the
//     deep link completes authentication.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/auth/data/auth_providers.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';

/// Manages the reactive authentication state for the entire application.
///
/// State machine:
///   AsyncLoading  →  (stream emits)  →  AsyncData(AuthStatus)
///   AsyncData(*)  →  login error     →  AsyncError
///   AsyncData(*)  →  login success   →  AsyncData(authenticated) via stream
///   AsyncData(*)  →  logout          →  AsyncData(unauthenticated) via stream
///   AsyncData(*)  →  register (email confirm ON) → AsyncData(pendingEmailConfirmation)
class AuthNotifier extends AsyncNotifier<AuthStatus> {
  @override
  Future<AuthStatus> build() async {
    final repo = ref.watch(authRepositoryProvider);

    // Use a Completer so state is driven entirely by the stream.
    // The future returned by build() never resolves — Riverpod stays in
    // AsyncLoading until the stream listener below sets state directly.
    final completer = Completer<AuthStatus>();

    final sub = repo.onAuthStateChange.listen(
      (status) {
        if (!completer.isCompleted) {
          // Resolve the build() future with the first emitted status
          completer.complete(status);
        } else {
          // For subsequent events, update state directly
          // Don't override pendingEmailConfirmation with unauthenticated
          // unless it's an explicit signedIn or signedOut event.
          if (status == AuthStatus.authenticated) {
            state = AsyncData(status);
          } else if (status == AuthStatus.unauthenticated) {
            // Only reset to unauthenticated if we're not in pendingEmailConfirmation
            final current = state.valueOrNull;
            if (current != AuthStatus.pendingEmailConfirmation) {
              state = AsyncData(status);
            }
          }
        }
      },
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        } else {
          state = AsyncError(e, st);
        }
      },
    );

    ref.onDispose(sub.cancel);

    return completer.future;
  }

  /// Sign in with email and password.
  ///
  /// State transitions to [AsyncData(authenticated)] via the auth stream on
  /// success, or [AsyncError] on failure.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      await ref.read(authRepositoryProvider).signInWithPassword(
            email: email,
            password: password,
          );
      // State updated by stream listener — no manual set needed.
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Send a magic-link OTP to [email].
  ///
  /// Does NOT change auth state — authentication happens when the user clicks
  /// the deep-link and the SDK fires an auth event.
  ///
  /// Sets [AsyncError] on failure.
  Future<void> sendMagicLink({required String email}) async {
    try {
      await ref.read(authRepositoryProvider).signInWithOtp(
            email: email,
            redirectTo: 'io.michangan.app://login-callback',
          );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Register a new user with email and password.
  ///
  /// Passes [emailRedirectTo] for mobile deep-link confirmation.
  ///
  /// When Supabase has email confirmation ON:
  ///   - signUp() succeeds but no signedIn event is emitted immediately.
  ///   - We set state to [AsyncData(pendingEmailConfirmation)] so the UI
  ///     can show a "check your email" message instead of a frozen spinner.
  ///
  /// When email confirmation is OFF (auto-confirm):
  ///   - signUp() causes a signedIn event → state goes to authenticated.
  ///
  /// Sets [AsyncError] on failure (duplicate email, weak password, etc.).
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      // Snapshot the state before the signUp call.
      final stateBefore = state;

      await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            redirectTo: 'io.michangan.app://login-callback',
          );

      // Give the stream a chance to fire (microtask queue + one frame).
      await Future.microtask(() {});
      await Future.delayed(const Duration(milliseconds: 100));

      // If state changed to authenticated, stream already handled it.
      // If state is unchanged (still unauthenticated = email confirm ON),
      // set pendingEmailConfirmation to unblock the UI spinner.
      final stateAfter = state;
      final stillUnchanged = stateAfter.valueOrNull == stateBefore.valueOrNull &&
          stateAfter.valueOrNull != AuthStatus.authenticated;

      if (stillUnchanged) {
        state = const AsyncData(AuthStatus.pendingEmailConfirmation);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Sign out the current user.
  ///
  /// State transitions to [AsyncData(unauthenticated)] via the stream when
  /// the signedOut event is emitted.
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
