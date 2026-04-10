// theme_notifier.dart
//
// Domain-layer AsyncNotifier for the app theme preference.
//
// Design decisions:
//   - AsyncNotifier<ThemeMode> — async because loading persisted preference
//     on startup (SharedPreferences read is async).
//   - build() loads the stored preference via ThemePersistence.
//   - setTheme() persists then updates state immediately (optimistic).
//   - toggleTheme() cycles: light → dark, dark → light, system → light.
//   - No dependency on Flutter widgets — ThemeMode is a flutter/material enum
//     but is pure data here; safe for unit tests without a widget tree.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/theme/theme_persistence.dart';

/// Manages the reactive app theme preference.
class ThemeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final persistence = ref.watch(themePersistenceProvider);
    return persistence.loadTheme();
  }

  /// Persist and apply [mode].
  Future<void> setTheme(ThemeMode mode) async {
    final persistence = ref.read(themePersistenceProvider);
    await persistence.saveTheme(mode);
    state = AsyncData(mode);
  }

  /// Toggle between [ThemeMode.light] and [ThemeMode.dark].
  ///
  /// [ThemeMode.system] → [ThemeMode.light] as the first manual toggle.
  Future<void> toggleTheme() async {
    final current = state.valueOrNull ?? ThemeMode.system;
    final next = switch (current) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system => ThemeMode.light,
    };
    await setTheme(next);
  }
}
