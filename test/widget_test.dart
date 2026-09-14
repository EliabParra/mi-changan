// widget_test.dart
//
// Secondary widget smoke test.
// Migrated to H2 router: the app now starts at /login for unauthenticated users.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_changan/app.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';

void main() {
  testWidgets('renders app root title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeUnauthNotifier()),
        ],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    // App starts at /login for unauthenticated users
    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });
}

class _FakeUnauthNotifier extends AuthNotifier {
  @override
  Future<AuthStatus> build() async {
    state = const AsyncData(AuthStatus.unauthenticated);
    return AuthStatus.unauthenticated;
  }
}
