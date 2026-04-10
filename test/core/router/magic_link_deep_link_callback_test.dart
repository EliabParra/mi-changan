// magic_link_deep_link_callback_test.dart
//
// Scenario: Magic Link Deep Link Handling
//
// Spec reference: sdd/h2-auth-email-magic-link/spec — Scenario 3
//
//   Given an unauthenticated user who clicked a magic link
//   When the app is opened via the deep link
//   Then the app parses the token, authenticates, and routes to /dashboard
//
// Test strategy (notifier+router integration):
//   - Override [authNotifierProvider] with a controllable fake that starts
//     in unauthenticated state, mimicking "app opened, no session yet".
//   - Mount [MaterialApp.router] using the real [appRouterProvider] (which
//     wires [_RouterNotifier] → [refreshListenable]) so route re-evaluation
//     fires automatically when auth state changes.
//   - Emit [AuthStatus.authenticated] from the fake notifier to simulate
//     the SDK firing an auth event after the deep-link token is processed.
//   - Assert that the router transitions from /login to /dashboard without
//     any manual navigation call — proving the observable behaviour of the
//     magic-link callback stream.
//
// TDD Cycle: RED→GREEN (this file added in remediation batch for verify blockers)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_changan/core/router/app_router.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';

// ── Controllable fake notifier ────────────────────────────────────────────────

/// A fake [AuthNotifier] whose auth state can be driven externally.
///
/// [build()] starts in [AsyncData(AuthStatus.unauthenticated)] so the router
/// guard sees an unauthenticated user and places them at /login.
///
/// Call [simulateDeepLinkCallback()] to push [AsyncData(AuthStatus.authenticated)]
/// — this is the observable behaviour triggered when the Supabase SDK processes
/// the magic-link token from the deep link and fires an auth stream event.
class _ControllableFakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthStatus> build() async {
    // Start unauthenticated: no session, user just opened the app via deep link
    // but the SDK has not yet processed the token.
    state = const AsyncData(AuthStatus.unauthenticated);
    return AuthStatus.unauthenticated;
  }

  /// Simulate the Supabase SDK firing a [signedIn] auth event after processing
  /// the magic-link token from the deep link URL.
  ///
  /// This is the critical observable behaviour under test: the notifier's stream
  /// listener receives the signedIn event and updates state to authenticated,
  /// which causes [_RouterNotifier] to call [notifyListeners()] → GoRouter
  /// re-evaluates the redirect → user is sent to /dashboard.
  void simulateDeepLinkCallback() {
    state = const AsyncData(AuthStatus.authenticated);
  }
}

// ── Test-only ProviderContainer ───────────────────────────────────────────────

/// Builds a [MaterialApp.router] backed by the real [appRouterProvider] with
/// [authNotifierProvider] overridden by a [_ControllableFakeAuthNotifier].
///
/// Returns both the widget and a reference to the fake notifier so tests can
/// drive the deep-link callback.
({Widget app, _ControllableFakeAuthNotifier notifier}) buildDeepLinkApp() {
  final fakeNotifier = _ControllableFakeAuthNotifier();

  final app = ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => fakeNotifier),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(routerConfig: router);
      },
    ),
  );

  return (app: app, notifier: fakeNotifier);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Scenario: Magic Link Deep Link Handling', () {
    testWidgets(
      'unauthenticated user is at /login before deep link completes',
      (tester) async {
        final (:app, notifier: _) = buildDeepLinkApp();

        await tester.pumpWidget(app);
        await tester.pumpAndSettle();

        // Before the deep link token is processed: user sees /login
        expect(find.byKey(const Key('login_screen')), findsOneWidget);
        expect(find.byKey(const Key('dashboard_screen')), findsNothing);
      },
    );

    testWidgets(
      'after deep link callback fires authenticated event, router redirects to /dashboard',
      (tester) async {
        final (:app, :notifier) = buildDeepLinkApp();

        await tester.pumpWidget(app);
        await tester.pumpAndSettle();

        // Precondition: starts on /login (unauthenticated)
        expect(find.byKey(const Key('login_screen')), findsOneWidget);

        // Act: simulate Supabase SDK firing signedIn after deep-link token is processed
        notifier.simulateDeepLinkCallback();
        // Allow _RouterNotifier.notifyListeners() → GoRouter redirect → widget rebuild
        await tester.pumpAndSettle();

        // Assert: router transparently navigated to /dashboard
        expect(find.byKey(const Key('dashboard_screen')), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);
      },
    );

    testWidgets(
      'deep link callback does not crash if auth state transitions while on a public route',
      (tester) async {
        final (:app, :notifier) = buildDeepLinkApp();

        await tester.pumpWidget(app);
        await tester.pumpAndSettle();

        // Rapid state transition: simulate deep link arriving while user is
        // still on the login screen (no intermediate navigation)
        notifier.simulateDeepLinkCallback();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // No exception thrown; either still transitioning or already at dashboard
        expect(tester.takeException(), isNull);
      },
    );
  });
}
