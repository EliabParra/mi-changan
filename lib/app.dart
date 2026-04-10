// app.dart
//
// Root widget — MaterialApp.router wired to GoRouter provider and AppTheme.
// Wrapped in ProviderScope in main.dart.
//
// The [GoRouter] instance is read from [appRouterProvider] so the router
// can reference [authNotifierProvider] for refreshListenable and redirect.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/router/app_router.dart';
import 'package:mi_changan/core/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Mi Changan',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
