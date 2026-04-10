// maintenance_screen.dart
//
// Maintenance reminders screen — lists reminders and provides CRUD actions.
//
// Design decisions:
//   - ConsumerWidget reads maintenanceNotifierProvider(userId).
//   - Placeholder userId from auth until Wave 3 wires auth context here.
//   - Each reminder shows label, nextServiceKm, and status badge.
//   - FAB triggers AddReminderDialog.
//   - Swipe-to-delete with confirmDialog guard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/maintenance/domain/maintenance_notifier_provider.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/presentation/reminder_status_badge.dart';

/// The maintenance reminders list screen.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO(Wave3): replace with actual userId from authNotifierProvider
    const userId = 'current-user';
    final asyncReminders = ref.watch(maintenanceNotifierProvider(userId));

    return Scaffold(
      key: const Key('maintenance_screen'),
      appBar: AppBar(title: const Text('Mantenimiento')),
      body: asyncReminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar recordatorios: $e',
            key: const Key('maintenance_error'),
          ),
        ),
        data: (reminders) => reminders.isEmpty
            ? const Center(
                child: Text(
                  'Sin recordatorios. Tocá + para agregar.',
                  key: Key('maintenance_empty'),
                ),
              )
            : ListView.builder(
                key: const Key('maintenance_list'),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  return _ReminderTile(
                    reminder: reminder,
                    userId: userId,
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('maintenance_add_fab'),
        onPressed: () => _showAddReminderDialog(context, ref, userId),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddReminderDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddReminderDialog(userId: userId),
    );
  }
}

// ── Reminder tile ─────────────────────────────────────────────────────────

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({
    required this.reminder,
    required this.userId,
  });

  final MaintenanceReminder reminder;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key('reminder_tile_${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        ref
            .read(maintenanceNotifierProvider(userId).notifier)
            .deleteReminder(reminder.id);
      },
      child: ListTile(
        key: Key('reminder_item_${reminder.id}'),
        title: Text(reminder.label),
        subtitle: Text(
          'Próximo: ${reminder.nextServiceKm.toStringAsFixed(0)} km',
        ),
        trailing: ReminderStatusBadge(status: reminder.status),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar recordatorio'),
        content: Text('¿Eliminar "${reminder.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ── Add reminder dialog ────────────────────────────────────────────────────

class _AddReminderDialog extends ConsumerStatefulWidget {
  const _AddReminderDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends ConsumerState<_AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController();
  final _lastServiceKmCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _intervalCtrl.dispose();
    _lastServiceKmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo recordatorio'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('reminder_label_field'),
              controller: _labelCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            TextFormField(
              key: const Key('reminder_interval_field'),
              controller: _intervalCtrl,
              decoration: const InputDecoration(labelText: 'Intervalo (km)'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n <= 0) ? 'Ingresá un valor positivo' : null;
              },
            ),
            TextFormField(
              key: const Key('reminder_last_km_field'),
              controller: _lastServiceKmCtrl,
              decoration:
                  const InputDecoration(labelText: 'Último servicio (km)'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n < 0) ? 'Ingresá un valor válido' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('reminder_save_button'),
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final reminder = MaintenanceReminder(
      id: _generateId(),
      userId: widget.userId,
      label: _labelCtrl.text.trim(),
      intervalKm: double.parse(_intervalCtrl.text),
      lastServiceKm: double.parse(_lastServiceKmCtrl.text),
      lastServiceDate: DateTime.now(),
    );

    ref
        .read(maintenanceNotifierProvider(widget.userId).notifier)
        .addReminder(reminder);
    Navigator.of(context).pop();
  }

  /// Generates a simple client-side UUID v4 placeholder.
  /// In production this is replaced by the Supabase-generated UUID.
  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
