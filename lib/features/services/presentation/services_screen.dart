// services_screen.dart
//
// Service records screen — lists records and provides add/delete actions.
//
// Design decisions:
//   - ConsumerWidget reads serviceNotifierProvider(userId).
//   - Linked to maintenanceNotifierProvider for reminder picker in AddRecordDialog.
//   - Placeholder userId until Wave 3 wires auth context.
//   - FAB triggers AddServiceRecordDialog.
//   - Swipe-to-delete.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/services/domain/service_notifier_provider.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_notifier_provider.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';

/// The service records list screen.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO(Wave3): replace with actual userId from authNotifierProvider
    const userId = 'current-user';
    final asyncRecords = ref.watch(serviceNotifierProvider(userId));

    return Scaffold(
      key: const Key('services_screen'),
      appBar: AppBar(title: const Text('Servicios')),
      body: asyncRecords.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar servicios: $e',
            key: const Key('services_error'),
          ),
        ),
        data: (records) => records.isEmpty
            ? const Center(
                child: Text(
                  'Sin registros. Tocá + para agregar.',
                  key: Key('services_empty'),
                ),
              )
            : ListView.builder(
                key: const Key('services_list'),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return _ServiceRecordTile(record: record, userId: userId);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('services_add_fab'),
        onPressed: () => _showAddRecordDialog(context, ref, userId),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddRecordDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddServiceRecordDialog(userId: userId),
    );
  }
}

// ── Service record tile ────────────────────────────────────────────────────

class _ServiceRecordTile extends ConsumerWidget {
  const _ServiceRecordTile({
    required this.record,
    required this.userId,
  });

  final ServiceRecord record;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key('service_tile_${record.id}'),
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
            .read(serviceNotifierProvider(userId).notifier)
            .deleteRecord(record.id);
      },
      child: ListTile(
        key: Key('service_item_${record.id}'),
        title: Text(record.reminderLabel),
        subtitle: Text(
          '${record.odometerKm.toStringAsFixed(0)} km — '
          '\$${record.costUsd.toStringAsFixed(2)}',
        ),
        trailing: Text(
          '${record.serviceDate.day}/${record.serviceDate.month}/${record.serviceDate.year}',
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Eliminar servicio "${record.reminderLabel}"?'),
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

// ── Add service record dialog ──────────────────────────────────────────────

class _AddServiceRecordDialog extends ConsumerStatefulWidget {
  const _AddServiceRecordDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_AddServiceRecordDialog> createState() =>
      _AddServiceRecordDialogState();
}

class _AddServiceRecordDialogState
    extends ConsumerState<_AddServiceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _odometerCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _workshopCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  MaintenanceReminder? _selectedReminder;

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _costCtrl.dispose();
    _workshopCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncReminders =
        ref.watch(maintenanceNotifierProvider(widget.userId));

    return AlertDialog(
      title: const Text('Nuevo servicio'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              asyncReminders.when(
                loading: () =>
                    const CircularProgressIndicator(key: Key('reminders_loading')),
                error: (e, _) => Text('Error: $e'),
                data: (reminders) => DropdownButtonFormField<MaintenanceReminder>(
                  key: const Key('service_reminder_dropdown'),
                  hint: const Text('Tipo de servicio'),
                  initialValue: _selectedReminder,
                  items: reminders
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        ),
                      )
                      .toList(),
                  onChanged: (r) => setState(() => _selectedReminder = r),
                  validator: (v) => v == null ? 'Seleccioná un tipo' : null,
                ),
              ),
              TextFormField(
                key: const Key('service_odometer_field'),
                controller: _odometerCtrl,
                decoration:
                    const InputDecoration(labelText: 'Odómetro al servicio (km)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return (n == null || n < 0)
                      ? 'Ingresá un valor válido'
                      : null;
                },
              ),
              TextFormField(
                key: const Key('service_cost_field'),
                controller: _costCtrl,
                decoration:
                    const InputDecoration(labelText: 'Costo (USD)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return (n == null || n < 0)
                      ? 'Ingresá un valor válido'
                      : null;
                },
              ),
              TextFormField(
                key: const Key('service_workshop_field'),
                controller: _workshopCtrl,
                decoration:
                    const InputDecoration(labelText: 'Taller (opcional)'),
              ),
              TextFormField(
                key: const Key('service_notes_field'),
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('service_save_button'),
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final reminder = _selectedReminder!;
    final record = ServiceRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: widget.userId,
      reminderId: reminder.id,
      reminderLabel: reminder.label,
      odometerKm: double.parse(_odometerCtrl.text),
      costUsd: double.parse(_costCtrl.text),
      serviceDate: DateTime.now(),
      workshopName:
          _workshopCtrl.text.trim().isEmpty ? null : _workshopCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    ref
        .read(serviceNotifierProvider(widget.userId).notifier)
        .addRecord(record);
    Navigator.of(context).pop();
  }
}
