// app_router.dart
//
// Centralized GoRouter configuration (AD6 — declarative routing baseline).
// Routes will be expanded per feature slice in H2+.
//
// Current routes:
//   /  → placeholder HomeScreen (replaced in H2 dashboard feature)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) =>
          const _PlaceholderHomeScreen(),
    ),
  ],
);

/// Temporary placeholder — replaced when dashboard feature is implemented.
class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Changan')),
      body: const Center(
        child: Text('Mi Changan — en construcción'),
      ),
    );
  }
}
