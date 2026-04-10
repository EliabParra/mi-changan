// maintenance_screen.dart
//
// Maintenance reminders screen — lists reminders with visual progress and CRUD.
//
// Design decisions:
//   - ConsumerWidget reads maintenanceNotifierProvider(userId).
//   - userId comes from currentUserIdProvider (Supabase session — null-safe).
//   - Each reminder tile shows a LinearProgressIndicator colored by status.
//   - Status color: upcoming=primary, due=amber, overdue=error.
//   - Tap tile opens _EditReminderDialog; swipe-to-delete with confirm guard.
//   - FAB triggers _AddReminderDialog.
//   - Progress clamped to [0..1] — overdue shows full red bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_notifier_provider.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/presentation/reminder_status_badge.dart';

/// The maintenance reminders list screen.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // No session yet — router will redirect to /login; show spinner meanwhile.
    if (userId == null) {
      return const Scaffold(
        key: Key('maintenance_screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final asyncReminders = ref.watch(maintenanceNotifierProvider(userId));

    return Scaffold(
      key: const Key('maintenance_screen'),
      appBar: AppBar(title: const Text('Mantenimiento')),
      body: asyncReminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text(
            'No se pudieron cargar los recordatorios. Intentá de nuevo.',
            key: Key('maintenance_error'),
            textAlign: TextAlign.center,
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
                padding: const EdgeInsets.symmetric(vertical: 8),
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
        onPressed: () => _showAddReminderDialog(context, userId),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context, String userId) {
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
    final statusColor = _statusColor(context, reminder.status);
    final progress = _progress(reminder);
    final kmRemaining = reminder.kmRemaining;

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
      child: Card(
        key: Key('reminder_item_${reminder.id}'),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEditDialog(context),
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
                        reminder.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ReminderStatusBadge(status: reminder.status),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Progress bar ────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: Key('reminder_progress_${reminder.id}'),
                    value: progress,
                    minHeight: 6,
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 6),

                // ── Detail row ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Próximo: ${reminder.nextServiceKm.toStringAsFixed(0)} km'
                        ' · Cada ${reminder.intervalKm.toStringAsFixed(0)} km',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (kmRemaining != null)
                      Text(
                        kmRemaining < 0
                            ? 'Vencido ${(-kmRemaining).toStringAsFixed(0)} km'
                            : 'Restan ${kmRemaining.toStringAsFixed(0)} km',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                  ],
                ),

                // ── Notes ───────────────────────────────────────────────
                if (reminder.notes != null &&
                    reminder.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _EditReminderDialog(reminder: reminder, userId: userId),
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

  /// Returns a progress value [0.0 – 1.0] for the LinearProgressIndicator.
  ///
  /// 0.0 = just serviced, 1.0 = at or past due km (overdue clamped to 1.0).
  static double _progress(MaintenanceReminder reminder) {
    final km = reminder.kmRemaining;
    if (km == null) return 0.0;
    final done = reminder.intervalKm - km;
    return (done / reminder.intervalKm).clamp(0.0, 1.0);
  }

  static Color _statusColor(BuildContext context, ReminderStatus status) =>
      switch (status) {
        ReminderStatus.upcoming => Theme.of(context).colorScheme.primary,
        ReminderStatus.due => Colors.amber.shade700,
        ReminderStatus.overdue => Theme.of(context).colorScheme.error,
      };
}

// ── Add reminder dialog ────────────────────────────────────────────────────

class _AddReminderDialog extends ConsumerStatefulWidget {
  const _AddReminderDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_AddReminderDialog> createState() =>
      _AddReminderDialogState();
}

class _AddReminderDialogState extends ConsumerState<_AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController();
  final _lastServiceKmCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _intervalCtrl.dispose();
    _lastServiceKmCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo recordatorio'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('reminder_label_field'),
                controller: _labelCtrl,
                decoration:
                    const InputDecoration(labelText: 'Descripción'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('reminder_interval_field'),
                controller: _intervalCtrl,
                decoration:
                    const InputDecoration(labelText: 'Intervalo (km)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n =
                      double.tryParse(v?.replaceAll(',', '.') ?? '');
                  return (n == null || n <= 0)
                      ? 'Ingresá un valor positivo'
                      : null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('reminder_last_km_field'),
                controller: _lastServiceKmCtrl,
                decoration: const InputDecoration(
                    labelText: 'Último servicio (km)'),
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
              TextFormField(
                key: const Key('reminder_notes_field'),
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
          key: const Key('reminder_save_button'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final reminder = MaintenanceReminder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: widget.userId,
      label: _labelCtrl.text.trim(),
      intervalKm:
          double.parse(_intervalCtrl.text.replaceAll(',', '.')),
      lastServiceKm:
          double.parse(_lastServiceKmCtrl.text.replaceAll(',', '.')),
      lastServiceDate: DateTime.now(),
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );

    try {
      await ref
          .read(maintenanceNotifierProvider(widget.userId).notifier)
          .addReminder(reminder);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se pudo guardar el recordatorio. Intentá de nuevo.'),
          ),
        );
      }
    }
  }
}

// ── Edit reminder dialog ───────────────────────────────────────────────────

class _EditReminderDialog extends ConsumerStatefulWidget {
  const _EditReminderDialog({
    required this.reminder,
    required this.userId,
  });

  final MaintenanceReminder reminder;
  final String userId;

  @override
  ConsumerState<_EditReminderDialog> createState() =>
      _EditReminderDialogState();
}

class _EditReminderDialogState
    extends ConsumerState<_EditReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _intervalCtrl;
  late final TextEditingController _lastServiceKmCtrl;
  late final TextEditingController _notesCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.reminder.label);
    _intervalCtrl = TextEditingController(
        text: widget.reminder.intervalKm.toStringAsFixed(0));
    _lastServiceKmCtrl = TextEditingController(
        text: widget.reminder.lastServiceKm.toStringAsFixed(0));
    _notesCtrl =
        TextEditingController(text: widget.reminder.notes ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _intervalCtrl.dispose();
    _lastServiceKmCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar recordatorio'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('reminder_edit_label_field'),
                controller: _labelCtrl,
                decoration:
                    const InputDecoration(labelText: 'Descripción'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('reminder_edit_interval_field'),
                controller: _intervalCtrl,
                decoration:
                    const InputDecoration(labelText: 'Intervalo (km)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n =
                      double.tryParse(v?.replaceAll(',', '.') ?? '');
                  return (n == null || n <= 0)
                      ? 'Ingresá un valor positivo'
                      : null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('reminder_edit_last_km_field'),
                controller: _lastServiceKmCtrl,
                decoration: const InputDecoration(
                    labelText: 'Último servicio (km)'),
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
              TextFormField(
                key: const Key('reminder_edit_notes_field'),
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
          key: const Key('reminder_edit_save_button'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final updated = MaintenanceReminder(
      id: widget.reminder.id,
      userId: widget.userId,
      label: _labelCtrl.text.trim(),
      intervalKm:
          double.parse(_intervalCtrl.text.replaceAll(',', '.')),
      lastServiceKm:
          double.parse(_lastServiceKmCtrl.text.replaceAll(',', '.')),
      lastServiceDate: widget.reminder.lastServiceDate,
      currentKm: widget.reminder.currentKm,
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );

    try {
      await ref
          .read(maintenanceNotifierProvider(widget.userId).notifier)
          .updateReminder(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se pudo actualizar el recordatorio. Intentá de nuevo.'),
          ),
        );
      }
    }
  }
}
