// settings_screen.dart
//
// App settings screen — theme toggle, km inicial, fechas, neumáticos,
// export/import JSON.
//
// Design decisions:
//   - ConsumerWidget reads themeNotifierProvider for current mode.
//   - ThemeMode toggle is a SegmentedButton (light / dark / system).
//   - Export reads mileage logs and shares/downloads the JSON.
//   - Import shows a text input dialog for paste (file picker deferred to
//     native platform integration — Wave 4).
//   - Km inicial, fecha de compra, neumáticos stored in SharedPreferences
//     via VehicleSettingsNotifier.
//   - No business logic in widget.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/core/theme/theme_notifier_provider.dart';
import 'package:mi_changan/features/mileage/domain/mileage_notifier_provider.dart';
import 'package:mi_changan/features/settings/domain/export_import_service.dart';
import 'package:mi_changan/features/settings/domain/vehicle_settings_notifier.dart';

/// Application settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTheme = ref.watch(themeNotifierProvider);
    final themeMode = asyncTheme.valueOrNull ?? ThemeMode.system;
    final vehicleSettings = ref.watch(vehicleSettingsProvider);

    return Scaffold(
      key: const Key('settings_screen'),
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Apariencia section ────────────────────────────────────────────
          const _SectionTitle('Apariencia', key: Key('settings_theme_section_title')),
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
          const SizedBox(height: 24),

          // ── Vehículo section ──────────────────────────────────────────────
          const _SectionTitle('Vehículo', key: Key('settings_vehicle_section_title')),
          const SizedBox(height: 8),

          vehicleSettings.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('No se pudieron cargar los ajustes del vehículo.'),
            data: (settings) => Column(
              children: [
                // Km inicial
                ListTile(
                  key: const Key('settings_initial_km_tile'),
                  leading: const Icon(Icons.speed),
                  title: const Text('Km inicial'),
                  subtitle: Text(settings.initialKm != null
                      ? '${settings.initialKm!.toStringAsFixed(0)} km'
                      : 'No configurado'),
                  trailing: const Icon(Icons.edit, size: 16),
                  onTap: () => _editInitialKm(context, ref, settings.initialKm),
                ),
                // Fecha de compra
                ListTile(
                  key: const Key('settings_purchase_date_tile'),
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Fecha de compra'),
                  subtitle: Text(settings.purchaseDate != null
                      ? '${settings.purchaseDate!.day}/${settings.purchaseDate!.month}/${settings.purchaseDate!.year}'
                      : 'No configurada'),
                  trailing: const Icon(Icons.edit, size: 16),
                  onTap: () => _editPurchaseDate(context, ref, settings.purchaseDate),
                ),
                // Neumáticos
                ListTile(
                  key: const Key('settings_tires_tile'),
                  leading: const Icon(Icons.tire_repair),
                  title: const Text('Km último cambio de neumáticos'),
                  subtitle: Text(settings.lastTireChangeKm != null
                      ? '${settings.lastTireChangeKm!.toStringAsFixed(0)} km'
                      : 'No configurado'),
                  trailing: const Icon(Icons.edit, size: 16),
                  onTap: () => _editTireKm(context, ref, settings.lastTireChangeKm),
                ),
                // Próximo servicio
                ListTile(
                  key: const Key('settings_next_service_tile'),
                  leading: const Icon(Icons.car_repair),
                  title: const Text('Km próximo servicio'),
                  subtitle: Text(settings.nextServiceKm != null
                      ? '${settings.nextServiceKm!.toStringAsFixed(0)} km'
                      : 'No configurado'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.nextServiceKm != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          tooltip: 'Borrar',
                          onPressed: () => ref
                              .read(vehicleSettingsProvider.notifier)
                              .clearNextServiceKm(),
                        ),
                      const Icon(Icons.edit, size: 16),
                    ],
                  ),
                  onTap: () =>
                      _editNextServiceKm(context, ref, settings.nextServiceKm),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Datos section ─────────────────────────────────────────────────
          const _SectionTitle('Datos', key: Key('settings_data_section_title')),
          const SizedBox(height: 8),

          ListTile(
            key: const Key('settings_export_tile'),
            leading: const Icon(Icons.upload),
            title: const Text('Exportar datos'),
            subtitle: const Text('Copiar JSON al portapapeles'),
            onTap: () => _exportData(context, ref),
          ),
          ListTile(
            key: const Key('settings_import_tile'),
            leading: const Icon(Icons.download),
            title: const Text('Importar datos'),
            subtitle: const Text('Pegar JSON para restaurar'),
            onTap: () => _importData(context, ref),
          ),
        ],
      ),
    );
  }

  // ── Edit handlers ──────────────────────────────────────────────────────────

  Future<void> _editInitialKm(
      BuildContext context, WidgetRef ref, double? current) async {
    final ctrl = TextEditingController(
        text: current != null ? current.toStringAsFixed(0) : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Km inicial del vehículo'),
        content: TextFormField(
          key: const Key('settings_initial_km_field'),
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Kilómetros al comprar',
            suffixText: 'km',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final km = double.tryParse(result);
      if (km != null) {
        await ref.read(vehicleSettingsProvider.notifier).setInitialKm(km);
      }
    }
  }

  Future<void> _editPurchaseDate(
      BuildContext context, WidgetRef ref, DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await ref.read(vehicleSettingsProvider.notifier).setPurchaseDate(picked);
    }
  }

  Future<void> _editNextServiceKm(
      BuildContext context, WidgetRef ref, double? current) async {
    final ctrl = TextEditingController(
        text: current != null ? current.toStringAsFixed(0) : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Km próximo servicio'),
        content: TextFormField(
          key: const Key('settings_next_service_km_field'),
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Odómetro en próximo servicio',
            hintText: 'ej: 50000',
            suffixText: 'km',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final km = double.tryParse(result);
      if (km != null) {
        await ref.read(vehicleSettingsProvider.notifier).setNextServiceKm(km);
      }
    }
  }

  Future<void> _editTireKm(
      BuildContext context, WidgetRef ref, double? current) async {
    final ctrl = TextEditingController(
        text: current != null ? current.toStringAsFixed(0) : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Último cambio de neumáticos'),
        content: TextFormField(
          key: const Key('settings_tires_km_field'),
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Km al cambiar neumáticos',
            suffixText: 'km',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final km = double.tryParse(result);
      if (km != null) {
        await ref.read(vehicleSettingsProvider.notifier).setLastTireChangeKm(km);
      }
    }
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider) ?? '';
    final asyncLogs = ref.read(mileageNotifierProvider(userId));

    asyncLogs.whenOrNull(
      data: (logs) async {
        final json = ExportImportService.exportToJson(mileageLogs: logs);
        await Clipboard.setData(ClipboardData(text: json));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Datos copiados al portapapeles.'),
            ),
          );
        }
      },
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cargando datos, esperá un momento...')),
        );
      },
      error: (_, __) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudieron cargar los datos para exportar.')),
        );
      },
    );
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar datos'),
        content: TextField(
          key: const Key('settings_import_field'),
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Pegá el JSON de exportación aquí...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('settings_import_confirm_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirmed != true || ctrl.text.trim().isEmpty) return;

    try {
      final result = ExportImportService.importFromJson(ctrl.text.trim());
      final userId = ref.read(currentUserIdProvider) ?? '';
      for (final log in result.mileageLogs) {
        await ref.read(mileageNotifierProvider(userId).notifier).addLog(log);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importación exitosa: ${result.mileageLogs.length} registros.',
            ),
          ),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El JSON no es válido. Revisá el formato.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Error al importar. Revisá los datos e intentá de nuevo.'),
          ),
        );
      }
    }
  }
}

// ── Section title helper ──────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
