// theme_notifier_provider.dart
//
// Riverpod provider for ThemeNotifier.
//
// Design decisions:
//   - AsyncNotifierProvider<ThemeNotifier, ThemeMode> — async for persistence load.
//   - Global singleton — one theme state for the whole app.
//   - App.dart watches this provider to drive MaterialApp.router themeMode.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/theme/theme_notifier.dart';
import 'package:flutter/material.dart';

/// Global provider for the app's reactive theme mode.
final themeNotifierProvider =
    AsyncNotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
