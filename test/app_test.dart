// app_test.dart
//
// Smoke test — verifies that the root App widget bootstraps and renders
// the login placeholder screen (initial route after H2 router migration).
//
// TDD Batch C migration:
//   The old home_placeholder route is replaced by the auth-guarded router.
//   App now starts at /login (unauthenticated initial route).
//   authNotifierProvider is overridden to avoid Supabase initialization in tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_changan/app.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';

void main() {
  group('App bootstrap', () {
    testWidgets(
        'renders login placeholder when user is unauthenticated at startup',
        (WidgetTester tester) async {
      // Arrange: override auth notifier so no Supabase call is made
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider
                .overrideWith(() => _FakeUnauthNotifier()),
          ],
          child: const App(),
        ),
      );

      // Act: settle all pending frames
      await tester.pumpAndSettle();

      // Assert: login screen is shown as the initial unauthenticated route
      expect(find.byKey(const Key('login_screen')), findsOneWidget);
    });

    // TRIANGULATE — authenticated path: App redirects to dashboard
    testWidgets(
        'renders dashboard placeholder when user is already authenticated',
        (WidgetTester tester) async {
      // Arrange: override auth notifier with authenticated state
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider
                .overrideWith(() => _FakeAuthNotifier()),
          ],
          child: const App(),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: guard redirected /login → /dashboard for authenticated user
      expect(find.byKey(const Key('dashboard_screen')), findsOneWidget);
      expect(find.byKey(const Key('login_screen')), findsNothing);
    });
  });
}

// ── Minimal fake notifiers ────────────────────────────────────────────────────

class _FakeUnauthNotifier extends AuthNotifier {
  @override
  Future<AuthStatus> build() async {
    state = const AsyncData(AuthStatus.unauthenticated);
    return AuthStatus.unauthenticated;
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthStatus> build() async {
    state = const AsyncData(AuthStatus.authenticated);
    return AuthStatus.authenticated;
  }
}
