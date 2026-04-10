// dashboard_screen.dart
//
// Dashboard placeholder — Batch D, task 5.2.
//
// Design decisions:
//   - Minimal implementation per spec: "only a placeholder is required".
//   - Key('dashboard_screen') is REQUIRED — existing router tests (Batch C) and
//     app_test.dart rely on this key to verify authenticated navigation.
//   - Provides a working logout CTA (delegates to authNotifierProvider.logout()).
//   - Full dashboard business logic is out of scope for H2 (spec section 3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('dashboard_screen'),
      appBar: AppBar(
        title: const Text('Mi Changan'),
        actions: [
          IconButton(
            key: const Key('dashboard_logout_button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Dashboard — próximamente',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
