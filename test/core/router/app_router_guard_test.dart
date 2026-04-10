// app_router_guard_test.dart
//
// TDD Batch C — Task 4.1 RED
// Widget/router tests for the redirect matrix:
//
//   Unauthenticated user:
//     - can reach /login
//     - can reach /register
//     - redirected from /dashboard → /login
//
//   Authenticated user:
//     - redirected from /login → /dashboard
//     - redirected from /register → /dashboard
//     - can reach /dashboard
//
//   Loading/unknown state:
//     - splash placeholder shown (no crash, deterministic)
//
// Test strategy: override authNotifierProvider with a fixed AsyncValue,
// then pump a MaterialApp.router backed by the guarded GoRouter provider,
// and assert the final location using GoRouter.of(context).routerDelegate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_changan/core/router/app_router.dart';
import 'package:mi_changan/core/router/route_names.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Builds a testable [MaterialApp.router] backed by [appRouterProvider].
///
/// [authState] controls what [authNotifierProvider] returns —
/// this is the SSOT the guard reads.
Widget buildRouterApp({
  required AsyncValue<AuthStatus> authState,
  String initialLocation = RouteNames.login,
}) {
  final router = buildAppRouter(
    authState: authState,
    initialLocation: initialLocation,
  );
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(authState)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

/// A minimal fake [AuthNotifier] that returns a fixed [AsyncValue<AuthStatus>].
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._fixedState);
  final AsyncValue<AuthStatus> _fixedState;

  @override
  Future<AuthStatus> build() async {
    // Immediately set state to the injected value
    state = _fixedState;
    // Return a value so the Future completes
    return _fixedState.value ?? AuthStatus.unauthenticated;
  }
}

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  // ── Unauthenticated user ──────────────────────────────────────────────────

  group('Unauthenticated user', () {
    const unauthState = AsyncData(AuthStatus.unauthenticated);

    testWidgets('can access /login — no redirect', (tester) async {
      await tester.pumpWidget(buildRouterApp(
        authState: unauthState,
        initialLocation: RouteNames.login,
      ));
      await tester.pumpAndSettle();

      // The /login route is accessible: login screen key must be present
      expect(find.byKey(const Key('login_screen')), findsOneWidget);
    });

    testWidgets('can access /register — no redirect', (tester) async {
      await tester.pumpWidget(buildRouterApp(
        authState: unauthState,
        initialLocation: RouteNames.register,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register_screen')), findsOneWidget);
    });

    testWidgets('redirected from /dashboard → /login', (tester) async {
      await tester.pumpWidget(buildRouterApp(
        authState: unauthState,
        initialLocation: RouteNames.dashboard,
      ));
      await tester.pumpAndSettle();

      // Guard must redirect to /login
      expect(find.byKey(const Key('login_screen')), findsOneWidget);
      // Dashboard must NOT be visible
      expect(find.byKey(const Key('dashboard_screen')), findsNothing);
    });
  });

  // ── Authenticated user ────────────────────────────────────────────────────

  group('Authenticated user', () {
    const authState = AsyncData(AuthStatus.authenticated);

    testWidgets('redirected from /login → /dashboard', (tester) async {
      await tester.pumpWidget(buildRouterApp(
        authState: authState,
        initialLocation: RouteNames.login,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_screen')), findsOneWidget);
      expect(find.byKey(const Key('login_screen')), findsNothing);
    });

    testWidgets('redirected from /register → /dashboard', (tester) async {
      await tester.pumpWidget(buildRouterApp(
        authState: authState,
        initialLocation: RouteNames.register,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_screen')), findsOneWidget);
      expect(find.byKey(const Key('register_screen')), findsNothing);
    });

    testWidgets('can access /dashboard — no redirect', (tester) async {
      await tester.pumpWidget(buildRouterApp(
        authState: authState,
        initialLocation: RouteNames.dashboard,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_screen')), findsOneWidget);
    });
  });

  // ── Loading/unknown auth state ────────────────────────────────────────────

  group('Loading/unknown auth state', () {
    const loadingState = AsyncLoading<AuthStatus>();

    testWidgets('shows splash screen — no crash while auth resolves',
        (tester) async {
      await tester.pumpWidget(buildRouterApp(
        authState: loadingState,
        initialLocation: RouteNames.login,
      ));
      // Only pump once — we want to capture the loading state
      await tester.pump();

      // Splash screen key must appear (no crash, deterministic)
      expect(find.byKey(const Key('splash_screen')), findsOneWidget);
    });
  });
}
