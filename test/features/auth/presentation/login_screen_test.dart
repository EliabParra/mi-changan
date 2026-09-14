// login_screen_test.dart
//
// TDD Batch D — Task 5.1 RED → GREEN
// Widget tests for LoginScreen:
//
//   Validations:
//     - Empty email + empty password → shows validation errors
//     - Invalid email format → email validation error
//     - Empty password → password validation error
//
//   Loading state:
//     - Auth state AsyncLoading → form fields and buttons disabled
//
//   CTA actions:
//     - Tap "Iniciar sesión" with valid data → calls notifier.login()
//     - Tap "Enviar enlace mágico" with valid email → calls notifier.sendMagicLink()
//
//   Error feedback:
//     - AsyncError in auth state → SnackBar shows the error message
//
// Test strategy:
//   - Override authNotifierProvider with a FakeAuthNotifier
//   - Wrap in GoRouter context (LoginScreen uses context.push/go)
//   - For loading tests: use a fake that never resolves build() (hangs in AsyncLoading)
//   - For CTA tests: use pump() with a small duration to avoid pumpAndSettle
//     blocking on CircularProgressIndicator animation

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mi_changan/features/auth/domain/auth_notifier.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';
import 'package:mi_changan/features/auth/presentation/login_screen.dart';

// ── Fake notifiers ────────────────────────────────────────────────────────────

/// Normal fake: immediately resolves to [_initialState].
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initialState);
  final AsyncValue<AuthStatus> _initialState;

  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastMagicLinkEmail;
  int loginCallCount = 0;
  int magicLinkCallCount = 0;

  @override
  Future<AuthStatus> build() async {
    state = _initialState;
    return _initialState.value ?? AuthStatus.unauthenticated;
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    loginCallCount++;
    lastLoginEmail = email;
    lastLoginPassword = password;
    // Do NOT change state — caller checks loginCallCount
  }

  @override
  Future<void> sendMagicLink({required String email}) async {
    magicLinkCallCount++;
    lastMagicLinkEmail = email;
    // Do NOT change state — magic link sent success is handled separately
  }
}

/// Loading fake: build() never completes — keeps state in AsyncLoading.
class _LoadingAuthNotifier extends AuthNotifier {
  @override
  Future<AuthStatus> build() async {
    // Completer that never resolves → state stays AsyncLoading
    return Completer<AuthStatus>().future;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget buildLoginScreenApp({
  required AuthNotifier fakeNotifier,
}) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const Scaffold(
          key: Key('register_screen'),
          body: Text('Register'),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const Scaffold(
          key: Key('dashboard_screen'),
          body: Text('Dashboard'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => fakeNotifier),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Form validations ───────────────────────────────────────────────────────

  group('LoginScreen — form validations', () {
    testWidgets('empty email and password shows validation errors',
        (tester) async {
      final notifier = _FakeAuthNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildLoginScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      // Verify LoginScreen is rendered
      expect(find.byKey(const Key('login_screen')), findsOneWidget);

      // Tap submit with empty fields
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Both validation errors should appear
      expect(find.text('Ingresá tu email'), findsOneWidget);
      expect(find.text('Ingresá tu contraseña'), findsOneWidget);

      // Notifier must NOT have been called
      expect(notifier.loginCallCount, 0);
    });

    testWidgets('invalid email format shows email validation error',
        (tester) async {
      final notifier = _FakeAuthNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildLoginScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'notanemail',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Email inválido'), findsOneWidget);
      expect(notifier.loginCallCount, 0);
    });

    testWidgets('empty password shows password validation error', (tester) async {
      final notifier = _FakeAuthNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildLoginScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'user@example.com',
      );
      // Leave password empty
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ingresá tu contraseña'), findsOneWidget);
      expect(notifier.loginCallCount, 0);
    });
  });

  // ── Loading state ──────────────────────────────────────────────────────────

  group('LoginScreen — loading state', () {
    testWidgets('buttons are disabled when auth state is AsyncLoading',
        (tester) async {
      // _LoadingAuthNotifier never resolves build() → state stays AsyncLoading
      await tester.pumpWidget(
        buildLoginScreenApp(fakeNotifier: _LoadingAuthNotifier()),
      );
      // Single pump — state is AsyncLoading, build() hasn't resolved yet
      await tester.pump();

      // Submit button must be disabled (onPressed == null)
      final submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('login_submit_button')),
      );
      expect(submitBtn.onPressed, isNull);

      // Magic link button must also be disabled
      final magicBtn = tester.widget<OutlinedButton>(
        find.byKey(const Key('login_magic_link_button')),
      );
      expect(magicBtn.onPressed, isNull);
    });
  });

  // ── CTA actions ───────────────────────────────────────────────────────────

  group('LoginScreen — CTA actions', () {
    testWidgets('valid email + password calls notifier.login()', (tester) async {
      final notifier = _FakeAuthNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildLoginScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'password123',
      );

      await tester.tap(find.byKey(const Key('login_submit_button')));
      // Use pump() instead of pumpAndSettle() — the screen may enter a
      // loading state (CircularProgressIndicator) which prevents settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifier.loginCallCount, 1);
      expect(notifier.lastLoginEmail, 'user@example.com');
      expect(notifier.lastLoginPassword, 'password123');
    });

    testWidgets(
        'valid email + tap magic link button calls notifier.sendMagicLink()',
        (tester) async {
      final notifier = _FakeAuthNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildLoginScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'user@example.com',
      );

      await tester.tap(find.byKey(const Key('login_magic_link_button')));
      // Use pump() to let the async handler run without waiting for animations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifier.magicLinkCallCount, 1);
      expect(notifier.lastMagicLinkEmail, 'user@example.com');
    });

    testWidgets('empty email prevents magic link call', (tester) async {
      final notifier = _FakeAuthNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildLoginScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      // Do not enter email
      await tester.tap(find.byKey(const Key('login_magic_link_button')));
      await tester.pumpAndSettle();

      // Validation error must appear
      expect(find.text('Ingresá tu email'), findsOneWidget);
      expect(notifier.magicLinkCallCount, 0);
    });
  });

  // ── Error feedback ─────────────────────────────────────────────────────────

  group('LoginScreen — error feedback', () {
    testWidgets('AsyncError state shows SnackBar with error message',
        (tester) async {
      final notifier = _FakeAuthNotifier(
        AsyncError(
          Exception('Email o contraseña incorrectos'),
          StackTrace.empty,
        ),
      );
      await tester.pumpWidget(buildLoginScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      // SnackBar must display a user-friendly error message
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Email o contraseña incorrectos'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping register link navigates to /register', (tester) async {
      final notifier = _FakeAuthNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildLoginScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_register_link')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register_screen')), findsOneWidget);
    });
  });
}
