// theme_persistence.dart
//
// Abstract interface + Riverpod provider for theme preference persistence.
//
// Design decisions:
//   - Interface-first — production uses SharedPreferences (added when
//     shared_preferences is added to pubspec); tests inject FakeThemePersistence.
//   - ThemeMode.name ('light'/'dark'/'system') used as the stored string key.
//   - The interface is kept intentionally thin: save and load only.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

/// Abstract interface for persisting the user's theme preference.
abstract class ThemePersistence {
  /// Persist [mode] so it survives app restarts.
  Future<void> saveTheme(ThemeMode mode);

  /// Load the previously persisted [ThemeMode].
  ///
  /// Returns [ThemeMode.system] when no value has been saved yet.
  Future<ThemeMode> loadTheme();
}

/// Riverpod provider for [ThemePersistence].
///
/// Overridden in tests with a [FakeThemePersistence].
/// Production override is registered in `main.dart` via ProviderScope overrides
/// once shared_preferences is added.
final themePersistenceProvider = Provider<ThemePersistence>((ref) {
  return const SharedPreferencesThemePersistence();
});

/// SharedPreferences-backed implementation for theme persistence.
class SharedPreferencesThemePersistence implements ThemePersistence {
  const SharedPreferencesThemePersistence();

  @override
  Future<void> saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }

  @override
  Future<ThemeMode> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeModeKey);
    if (raw == null) return ThemeMode.system;

    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }
}
