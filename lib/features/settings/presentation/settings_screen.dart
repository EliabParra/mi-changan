// settings_screen.dart
//
// App settings screen — theme toggle and (future) export/import.
//
// Design decisions:
//   - ConsumerWidget reads themeNotifierProvider for current mode.
//   - ThemeMode toggle is a SegmentedButton (light / dark / system).
//   - No business logic in widget — all persistence goes through ThemeNotifier.
//   - Export/Import section is stubbed (Wave 1 task 1.3, left as placeholder).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/theme/theme_notifier_provider.dart';

/// Application settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTheme = ref.watch(themeNotifierProvider);
    final themeMode = asyncTheme.valueOrNull ?? ThemeMode.system;

    return Scaffold(
      key: const Key('settings_screen'),
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Theme section ────────────────────────────────────────────
          Text(
            'Apariencia',
            key: const Key('settings_theme_section_title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            key: const Key('settings_theme_selector'),
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Claro'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Sistema'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Oscuro'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref
                  .read(themeNotifierProvider.notifier)
                  .setTheme(selection.first);
            },
          ),
          const SizedBox(height: 32),

          // ── Export / Import section (stub) ───────────────────────────
          Text(
            'Datos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const ListTile(
            key: Key('settings_export_tile'),
            leading: Icon(Icons.upload),
            title: Text('Exportar datos'),
            subtitle: Text('Próximamente'),
            enabled: false,
          ),
          const ListTile(
            key: Key('settings_import_tile'),
            leading: Icon(Icons.download),
            title: Text('Importar datos'),
            subtitle: Text('Próximamente'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
