// mileage_screen.dart
//
// Mileage logs screen — alta modo odómetro + modo distancia, historial y eliminar.
//
// Design decisions:
//   - MileageBody: body-only widget for use inside AppShell's IndexedStack
//     (no Scaffold/AppBar — the shell provides the outer Scaffold).
//   - MileageScreen: full Scaffold for standalone / deep-link use.
//   - ConsumerWidget — reads mileageNotifierProvider(userId).
//   - Two input modes: odómetro (total km reading) and distancia (trip km).
//   - userId comes from currentUserIdProvider (Supabase session — null-safe).
//   - If userId is null the body shows a loading indicator while the router
//     redirects unauthenticated users to /login.
//   - FAB triggers AddMileageLogDialog.
//   - Swipe-to-delete with confirm guard.
//   - Error messages are friendly Spanish.
//   - No business logic in widget — delegates to notifier.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log_queries.dart';
import 'package:mi_changan/features/mileage/domain/mileage_notifier_provider.dart';
import 'package:mi_changan/features/mileage/domain/mileage_temporal_validator.dart';
import 'package:mi_changan/features/mileage/presentation/mileage_datetime_picker.dart';

/// Full mileage screen with Scaffold — for standalone / deep-link use.
class MileageScreen extends ConsumerWidget {
  const MileageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('mileage_screen'),
      appBar: AppBar(title: const Text('Kilometraje')),
      body: const MileageBody(),
    );
  }
}

/// Mileage body widget — used inside AppShell's IndexedStack.
///
/// Does NOT include a Scaffold or AppBar — the shell provides those.
class MileageBody extends ConsumerWidget {
  const MileageBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // No session yet — router will redirect to /login; show spinner meanwhile.
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final asyncLogs = ref.watch(mileageNotifierProvider(userId));

    return Scaffold(
      // Inner Scaffold needed for FAB placement within the IndexedStack body.
      // AppBar is intentionally omitted — the outer shell has none for this tab;
      // the tab label in NavigationBar serves as context.
      body: asyncLogs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text(
            'No se pudieron cargar los registros. Intentá de nuevo.',
            key: Key('mileage_error'),
            textAlign: TextAlign.center,
          ),
        ),
        data: (logs) => logs.isEmpty
            ? const Center(
                child: Text(
                  'Sin registros. Tocá + para agregar.',
                  key: Key('mileage_empty'),
                ),
              )
            : _MileageList(logs: logs, userId: userId),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('mileage_add_fab'),
        onPressed: () => _showAddLogDialog(context, ref, userId),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddLogDialog(BuildContext context, WidgetRef ref, String userId) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddMileageLogDialog(userId: userId),
    );
  }
}

// ── Mileage list ──────────────────────────────────────────────────────────────

class _MileageList extends ConsumerWidget {
  const _MileageList({required this.logs, required this.userId});

  final List<MileageLog> logs;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      key: const Key('mileage_list'),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _MileageLogTile(log: log, userId: userId);
      },
    );
  }
}

// ── Log tile ──────────────────────────────────────────────────────────────────

class _MileageLogTile extends ConsumerWidget {
  const _MileageLogTile({required this.log, required this.userId});

  final MileageLog log;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final isTotal = log.entryType == MileageEntryType.total;

    return Dismissible(
      key: Key('mileage_tile_${log.id}'),
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
            .read(mileageNotifierProvider(userId).notifier)
            .deleteLog(log.id);
      },
      child: ListTile(
        key: Key('mileage_item_${log.id}'),
        leading: CircleAvatar(
          backgroundColor: isTotal
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            isTotal ? Icons.speed : Icons.route,
            size: 20,
            color: isTotal
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
          ),
        ),
        title: Text(
          isTotal
              ? '${log.valueKm.toStringAsFixed(0)} km (odómetro)'
              : '+${log.valueKm.toStringAsFixed(1)} km (distancia)',
        ),
        subtitle: Text(dateFmt.format(log.recordedAt.toLocal())),
        trailing: log.notes != null
            ? Tooltip(
                message: log.notes!,
                child: const Icon(Icons.notes, size: 16),
              )
            : null,
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('¿Eliminar este registro de kilometraje?'),
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

// ── Add mileage log dialog ─────────────────────────────────────────────────────

class _AddMileageLogDialog extends ConsumerStatefulWidget {
  const _AddMileageLogDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_AddMileageLogDialog> createState() =>
      _AddMileageLogDialogState();
}

class _AddMileageLogDialogState extends ConsumerState<_AddMileageLogDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _temporalValidator = const MileageTemporalValidator();

  MileageEntryType _entryType = MileageEntryType.total;
  bool _submitting = false;
  String? _temporalErrorMessage;
  DateTime _selectedLocalDateTime = DateTime.now();

  @override
  void dispose() {
    _valueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOdometer = _entryType == MileageEntryType.total;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return AlertDialog(
      title: const Text('Nuevo registro de km'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Mode selector ──────────────────────────────────────────────
            SegmentedButton<MileageEntryType>(
              key: const Key('mileage_entry_type_selector'),
              segments: const [
                ButtonSegment(
                  value: MileageEntryType.total,
                  label: Text('Odómetro'),
                  icon: Icon(Icons.speed),
                ),
                ButtonSegment(
                  value: MileageEntryType.distance,
                  label: Text('Distancia'),
                  icon: Icon(Icons.route),
                ),
              ],
              selected: {_entryType},
              onSelectionChanged: (s) =>
                  setState(() => _entryType = s.first),
            ),
            const SizedBox(height: 16),

            // ── Value field ────────────────────────────────────────────────
            TextFormField(
              key: const Key('mileage_value_field'),
              controller: _valueCtrl,
              decoration: InputDecoration(
                labelText:
                    isOdometer ? 'Lectura odómetro (km)' : 'Distancia recorrida (km)',
                hintText: isOdometer ? 'ej: 45320' : 'ej: 25.5',
                suffixText: 'km',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                if (n == null) return 'Ingresá un número válido';
                if (n < 0) return 'El valor debe ser positivo';
                if (isOdometer && n == 0) {
                  return 'El odómetro no puede ser 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ── Date/time selector ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fecha/hora: ${dateFmt.format(_selectedLocalDateTime)}',
                    key: const Key('mileage_datetime_text'),
                  ),
                ),
                TextButton.icon(
                  key: const Key('mileage_datetime_picker_button'),
                  onPressed: _submitting ? null : _pickDateTime,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Cambiar'),
                ),
              ],
            ),

            if (_temporalErrorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _temporalErrorMessage!,
                key: const Key('mileage_temporal_error_text'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),

            // ── Notes field ────────────────────────────────────────────────
            TextFormField(
              key: const Key('mileage_notes_field'),
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'ej: viaje a Caracas',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('mileage_save_button'),
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

  Future<void> _pickDateTime() async {
    final picker = ref.read(mileageDateTimePickerProvider);
    final picked = await picker.pick(context, _selectedLocalDateTime);
    if (picked == null || !mounted) return;

    setState(() {
      _selectedLocalDateTime = picked;
      _temporalErrorMessage = null;
    });
  }

  double? _latestTotalOdometerKm() {
    final logsState = ref.read(mileageNotifierProvider(widget.userId));
    return logsState.maybeWhen(
      data: latestTotalOdometerKm,
      orElse: () => null,
    );
  }

  Future<bool?> _confirmLowerOdometer() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar odómetro'),
        content: const Text(
          'El odómetro es menor al último registro. ¿Querés guardarlo igual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('mileage_confirm_lower_odometer_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar igual'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final rawValue = _valueCtrl.text.trim().replaceAll(',', '.');
    final valueKm = double.parse(rawValue);
    final selectedAtUtc = _selectedLocalDateTime.toUtc();

    final validationResult = _temporalValidator.validate(
      entryType: _entryType,
      valueKm: valueKm,
      selectedAtUtc: selectedAtUtc,
      nowUtc: DateTime.now().toUtc(),
      latestTotalOdometerKm: _latestTotalOdometerKm(),
    );

    if (!validationResult.isValid) {
      setState(() {
        _temporalErrorMessage = validationResult.message;
      });
      return;
    }

    if (validationResult.requiresLowerOdometerConfirmation) {
      final confirmed = await _confirmLowerOdometer();
      if (confirmed != true) return;
    }

    setState(() {
      _submitting = true;
      _temporalErrorMessage = null;
    });

    final log = MileageLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: widget.userId,
      entryType: _entryType,
      valueKm: valueKm,
      recordedAt: selectedAtUtc,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    try {
      await ref
          .read(mileageNotifierProvider(widget.userId).notifier)
          .addLog(log);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el registro. Intentá de nuevo.'),
          ),
        );
      }
    }
  }
}
