// services_screen.dart
//
// Service records screen — lists records and provides add/delete actions.
//
// Design decisions:
//   - ConsumerWidget reads serviceNotifierProvider(userId).
//   - Linked to maintenanceNotifierProvider for reminder picker in AddRecordDialog.
//   - userId comes from currentUserIdProvider (Supabase session — null-safe).
//   - If userId is null the screen shows a loading indicator while the router
//     redirects unauthenticated users to /login.
//   - FAB triggers _AddServiceRecordDialog.
//   - Swipe-to-delete with confirm guard.
//   - Tile shows service type, odometer, cost, date and optional workshop.
//   - Date picker allows selecting serviceDate (defaults to today).
//   - addRecord() in notifier also resets the linked reminder's baseline.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/features/services/domain/service_notifier_provider.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_notifier_provider.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/presentation/reminder_status_badge.dart';

/// The service records list screen.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // No session yet — router will redirect to /login; show spinner meanwhile.
    if (userId == null) {
      return const Scaffold(
        key: Key('services_screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final asyncRecords = ref.watch(serviceNotifierProvider(userId));

    return Scaffold(
      key: const Key('services_screen'),
      appBar: AppBar(title: const Text('Servicios')),
      body: asyncRecords.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text(
            'No se pudieron cargar los servicios. Intentá de nuevo.',
            key: Key('services_error'),
            textAlign: TextAlign.center,
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return _ServiceRecordTile(
                      record: record, userId: userId);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('services_add_fab'),
        onPressed: () => _showAddRecordDialog(context, userId),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddRecordDialog(BuildContext context, String userId) {
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
    final dateFmt = DateFormat('dd/MM/yyyy', 'es');

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
      child: Card(
        key: Key('service_item_${record.id}'),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.reminderLabel,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    dateFmt.format(record.serviceDate),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Detail row ──────────────────────────────────────────
              Row(
                children: [
                  // Odometer
                  _InfoChip(
                    icon: Icons.speed,
                    label:
                        '${record.odometerKm.toStringAsFixed(0)} km',
                  ),
                  const SizedBox(width: 8),
                  // Cost
                  _InfoChip(
                    icon: Icons.attach_money,
                    label:
                        '\$${record.costUsd.toStringAsFixed(2)}',
                  ),
                  // Workshop
                  if (record.workshopName != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: _InfoChip(
                        icon: Icons.build,
                        label: record.workshopName!,
                      ),
                    ),
                  ],
                ],
              ),

              // ── Notes ───────────────────────────────────────────────
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  record.notes!,
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
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

// ── Info chip ─────────────────────────────────────────────────────────────

/// Small inline chip: icon + label. Used in service record tiles.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
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
  DateTime _serviceDate = DateTime.now();
  bool _submitting = false;

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
    final dateFmt = DateFormat('dd/MM/yyyy', 'es');

    return AlertDialog(
      title: const Text('Nuevo servicio'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Reminder picker ──────────────────────────────────────
              asyncReminders.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      key: Key('reminders_loading')),
                ),
                error: (e, _) => Text(
                  'Error cargando recordatorios: $e',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
                data: (reminders) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<MaintenanceReminder>(
                      key: const Key('service_reminder_dropdown'),
                      hint: const Text('Tipo de servicio'),
                      initialValue: _selectedReminder,
                      isExpanded: true,
                      items: reminders
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (r) =>
                          setState(() => _selectedReminder = r),
                      validator: (v) =>
                          v == null ? 'Seleccioná un tipo' : null,
                    ),
                    // Show selected reminder's current status
                    if (_selectedReminder != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Estado actual: ',
                            style:
                                Theme.of(context).textTheme.bodySmall,
                          ),
                          ReminderStatusBadge(
                              status: _selectedReminder!.status),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Odometer ─────────────────────────────────────────────
              TextFormField(
                key: const Key('service_odometer_field'),
                controller: _odometerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Odómetro al servicio (km)',
                  suffixText: 'km',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n =
                      double.tryParse(v?.replaceAll(',', '.') ?? '');
                  return (n == null || n < 0)
                      ? 'Ingresá un valor válido'
                      : null;
                },
              ),
              const SizedBox(height: 8),

              // ── Cost ─────────────────────────────────────────────────
              TextFormField(
                key: const Key('service_cost_field'),
                controller: _costCtrl,
                decoration: const InputDecoration(
                  labelText: 'Costo (USD)',
                  prefixText: '\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n =
                      double.tryParse(v?.replaceAll(',', '.') ?? '');
                  return (n == null || n < 0)
                      ? 'Ingresá un valor válido'
                      : null;
                },
              ),
              const SizedBox(height: 8),

              // ── Date picker ───────────────────────────────────────────
              InkWell(
                key: const Key('service_date_picker'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha del servicio',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(dateFmt.format(_serviceDate)),
                ),
              ),
              const SizedBox(height: 8),

              // ── Workshop ──────────────────────────────────────────────
              TextFormField(
                key: const Key('service_workshop_field'),
                controller: _workshopCtrl,
                decoration: const InputDecoration(
                    labelText: 'Taller (opcional)'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),

              // ── Notes ─────────────────────────────────────────────────
              TextFormField(
                key: const Key('service_notes_field'),
                controller: _notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Notas (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('service_save_button'),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      setState(() => _serviceDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final reminder = _selectedReminder!;
    final record = ServiceRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: widget.userId,
      reminderId: reminder.id,
      reminderLabel: reminder.label,
      odometerKm: double.parse(
          _odometerCtrl.text.replaceAll(',', '.')),
      costUsd:
          double.parse(_costCtrl.text.replaceAll(',', '.')),
      serviceDate: _serviceDate,
      workshopName: _workshopCtrl.text.trim().isEmpty
          ? null
          : _workshopCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );

    try {
      await ref
          .read(serviceNotifierProvider(widget.userId).notifier)
          .addRecord(record);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se pudo guardar el servicio. Intentá de nuevo.'),
          ),
        );
      }
    }
  }
}
