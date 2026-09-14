// register_screen_test.dart
//
// TDD Batch D — Task 5.1 RED → GREEN
// Widget tests for RegisterScreen:
//
//   Validations:
//     - Empty all fields → validation errors on each
//     - Invalid email format → email validation error
//     - Short password (< 6 chars) → password strength error
//     - Passwords don't match → confirm password error
//
//   Loading state:
//     - Auth state AsyncLoading → register button disabled
//
//   CTA action:
//     - Valid email + password + confirm → calls notifier.register()
//
//   Error feedback:
//     - AsyncError in auth state → SnackBar shows the error message
//
//   Navigation:
//     - Tap "Ya tengo cuenta" link → navigates to /login

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mi_changan/features/auth/domain/auth_notifier.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';
import 'package:mi_changan/features/auth/presentation/register_screen.dart';

// ── Fake notifiers ────────────────────────────────────────────────────────────

class _FakeRegisterNotifier extends AuthNotifier {
  _FakeRegisterNotifier(this._initialState);
  final AsyncValue<AuthStatus> _initialState;

  String? lastRegisterEmail;
  String? lastRegisterPassword;
  int registerCallCount = 0;

  @override
  Future<AuthStatus> build() async {
    state = _initialState;
    return _initialState.value ?? AuthStatus.unauthenticated;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    registerCallCount++;
    lastRegisterEmail = email;
    lastRegisterPassword = password;
    // Do NOT change state — caller checks registerCallCount
  }
}

/// Loading fake: build() never completes — keeps state in AsyncLoading.
class _LoadingRegisterNotifier extends AuthNotifier {
  @override
  Future<AuthStatus> build() async {
    return Completer<AuthStatus>().future;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget buildRegisterScreenApp({
  required AuthNotifier fakeNotifier,
}) {
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(
          key: Key('login_screen'),
          body: Text('Login'),
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

  group('RegisterScreen — form validations', () {
    testWidgets('empty all fields shows validation errors on each field',
        (tester) async {
      final notifier = _FakeRegisterNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildRegisterScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      // Verify RegisterScreen is rendered
      expect(find.byKey(const Key('register_screen')), findsOneWidget);

      // Tap submit with all fields empty
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ingresá tu email'), findsOneWidget);
      expect(find.text('Ingresá tu contraseña'), findsOneWidget);
      expect(find.text('Confirmá tu contraseña'), findsOneWidget);

      expect(notifier.registerCallCount, 0);
    });

    testWidgets('invalid email format shows email validation error',
        (tester) async {
      final notifier = _FakeRegisterNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildRegisterScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'notanemail',
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Email inválido'), findsOneWidget);
      expect(notifier.registerCallCount, 0);
    });

    testWidgets('password shorter than 6 chars shows weak password error',
        (tester) async {
      final notifier = _FakeRegisterNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildRegisterScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        '12345', // 5 chars — too short
      );
      await tester.enterText(
        find.byKey(const Key('register_confirm_password_field')),
        '12345',
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('La contraseña debe tener al menos 6 caracteres'),
        findsOneWidget,
      );
      expect(notifier.registerCallCount, 0);
    });

    testWidgets('passwords do not match shows confirm password error',
        (tester) async {
      final notifier = _FakeRegisterNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildRegisterScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('register_confirm_password_field')),
        'differentpassword',
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(notifier.registerCallCount, 0);
    });
  });

  // ── Loading state ──────────────────────────────────────────────────────────

  group('RegisterScreen — loading state', () {
    testWidgets('submit button is disabled when auth state is AsyncLoading',
        (tester) async {
      // _LoadingRegisterNotifier never resolves build() → state stays AsyncLoading
      await tester.pumpWidget(
        buildRegisterScreenApp(fakeNotifier: _LoadingRegisterNotifier()),
      );
      await tester.pump();

      final submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('register_submit_button')),
      );
      expect(submitBtn.onPressed, isNull);
    });
  });

  // ── CTA action ────────────────────────────────────────────────────────────

  group('RegisterScreen — CTA action', () {
    testWidgets('valid form calls notifier.register() with correct credentials',
        (tester) async {
      final notifier = _FakeRegisterNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildRegisterScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'newuser@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'securepass',
      );
      await tester.enterText(
        find.byKey(const Key('register_confirm_password_field')),
        'securepass',
      );

      await tester.tap(find.byKey(const Key('register_submit_button')));
      // pump() to let the async handler complete without waiting for animations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifier.registerCallCount, 1);
      expect(notifier.lastRegisterEmail, 'newuser@example.com');
      expect(notifier.lastRegisterPassword, 'securepass');
    });
  });

  // ── Error feedback ─────────────────────────────────────────────────────────

  group('RegisterScreen — error feedback', () {
    testWidgets('AsyncError state shows SnackBar with error message',
        (tester) async {
      final notifier = _FakeRegisterNotifier(
        AsyncError(
          Exception('Este email ya está registrado'),
          StackTrace.empty,
        ),
      );
      await tester.pumpWidget(buildRegisterScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Este email ya está registrado'),
        ),
        findsOneWidget,
      );
    });
  });

  // ── Navigation ─────────────────────────────────────────────────────────────

  group('RegisterScreen — navigation', () {
    testWidgets('tapping login link navigates to /login', (tester) async {
      final notifier = _FakeRegisterNotifier(
        const AsyncData(AuthStatus.unauthenticated),
      );
      await tester.pumpWidget(buildRegisterScreenApp(fakeNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('register_login_link')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_screen')), findsOneWidget);
    });
  });
}
