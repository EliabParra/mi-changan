// theme_notifier_test.dart
//
// TDD — Task 3.3 RED
// Unit tests for ThemeNotifier state and ThemePersistence.
//
// Spec scenarios:
//   - Initial state is ThemeMode.system (app default)
//   - setTheme(light) changes state to ThemeMode.light
//   - setTheme(dark) changes state to ThemeMode.dark
//   - setTheme(system) changes state to ThemeMode.system
//   - toggleTheme() light → dark, dark → light, system → light
//   - Persistence: save and load round-trips ThemeMode correctly
//   - Persistence: loading unknown value returns ThemeMode.system

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/theme/theme_notifier_provider.dart';
import 'package:mi_changan/core/theme/theme_persistence.dart';

// ── Fake persistence ───────────────────────────────────────────────────────

class FakeThemePersistence implements ThemePersistence {
  String? _stored;

  @override
  Future<void> saveTheme(ThemeMode mode) async {
    _stored = mode.name;
  }

  @override
  Future<ThemeMode> loadTheme() async {
    if (_stored == null) return ThemeMode.system;
    return ThemeMode.values.firstWhere(
      (m) => m.name == _stored,
      orElse: () => ThemeMode.system,
    );
  }
}

// ── Container helper ───────────────────────────────────────────────────────

ProviderContainer makeContainer([ThemePersistence? persistence]) {
  return ProviderContainer(
    overrides: [
      themePersistenceProvider.overrideWithValue(
          persistence ?? FakeThemePersistence()),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('ThemeNotifier', () {
    test('initial state is ThemeMode.system', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(themeNotifierProvider.future);
      final mode = container.read(themeNotifierProvider).value;

      expect(mode, ThemeMode.system);
    });

    test('setTheme(light) changes state to light', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(themeNotifierProvider.future);
      await container
          .read(themeNotifierProvider.notifier)
          .setTheme(ThemeMode.light);

      final mode = container.read(themeNotifierProvider).value;
      expect(mode, ThemeMode.light);
    });

    test('setTheme(dark) changes state to dark', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(themeNotifierProvider.future);
      await container
          .read(themeNotifierProvider.notifier)
          .setTheme(ThemeMode.dark);

      final mode = container.read(themeNotifierProvider).value;
      expect(mode, ThemeMode.dark);
    });

    test('toggleTheme() light → dark', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(themeNotifierProvider.future);
      await container
          .read(themeNotifierProvider.notifier)
          .setTheme(ThemeMode.light);
      await container
          .read(themeNotifierProvider.notifier)
          .toggleTheme();

      final mode = container.read(themeNotifierProvider).value;
      expect(mode, ThemeMode.dark);
    });

    test('toggleTheme() dark → light', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(themeNotifierProvider.future);
      await container
          .read(themeNotifierProvider.notifier)
          .setTheme(ThemeMode.dark);
      await container
          .read(themeNotifierProvider.notifier)
          .toggleTheme();

      final mode = container.read(themeNotifierProvider).value;
      expect(mode, ThemeMode.light);
    });

    test('toggleTheme() system → light', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(themeNotifierProvider.future);
      // Initial is system
      await container
          .read(themeNotifierProvider.notifier)
          .toggleTheme();

      final mode = container.read(themeNotifierProvider).value;
      expect(mode, ThemeMode.light);
    });
  });

  group('ThemePersistence round-trip (FakeThemePersistence)', () {
    test('save and load preserves ThemeMode.dark', () async {
      final persistence = FakeThemePersistence();

      await persistence.saveTheme(ThemeMode.dark);
      final loaded = await persistence.loadTheme();

      expect(loaded, ThemeMode.dark);
    });

    test('save and load preserves ThemeMode.light', () async {
      final persistence = FakeThemePersistence();

      await persistence.saveTheme(ThemeMode.light);
      final loaded = await persistence.loadTheme();

      expect(loaded, ThemeMode.light);
    });

    test('load with no prior save returns ThemeMode.system', () async {
      final persistence = FakeThemePersistence();

      final loaded = await persistence.loadTheme();

      expect(loaded, ThemeMode.system);
    });
  });
}
