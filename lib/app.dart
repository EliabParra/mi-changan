// app.dart
//
// Root widget — MaterialApp.router wired to GoRouter provider, AppTheme,
// and ThemeNotifier for runtime dark/light toggle (H10).
// Wrapped in ProviderScope in main.dart.
//
// The [GoRouter] instance is read from [appRouterProvider] so the router
// can reference [authNotifierProvider] for refreshListenable and redirect.
// [themeNotifierProvider] drives themeMode reactively.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/router/app_router.dart';
import 'package:mi_changan/core/theme/app_theme.dart';
import 'package:mi_changan/core/theme/theme_notifier_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // AsyncValue<ThemeMode> — fallback to system while loading
    final themeMode =
        ref.watch(themeNotifierProvider).valueOrNull ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'Mi Changan',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
