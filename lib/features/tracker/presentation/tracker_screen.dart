// tracker_screen.dart
//
// Foreground GPS tracker screen.
//
// Design decisions:
//   - ConsumerWidget reads trackerNotifierProvider for state.
//   - Start/Stop buttons drive notifier calls.
//   - GPS hardware location stream is NOT wired yet (deferred to Wave 4
//     platform integration) — manual point injection via addPoint() is
//     sufficient for MVP domain testing.
//   - Shows current route point count and last known km when stopped.
//   - stopTracking() result (MileageLog) is handed to mileageRepositoryProvider
//     for persistence — placeholder userId until auth context is wired.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/tracker/domain/tracker_notifier_provider.dart';
import 'package:mi_changan/features/tracker/domain/tracker_state.dart';

/// Foreground GPS tracker screen — Start / Stop and route summary.
class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackerNotifierProvider);
    final isTracking = state.status == TrackerStatus.tracking;

    return Scaffold(
      key: const Key('tracker_screen'),
      appBar: AppBar(title: const Text('Tracker GPS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
              key: const Key('tracker_status_icon'),
              size: 64,
              color: isTracking ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isTracking ? 'Rastreando…' : 'Detenido',
              key: const Key('tracker_status_label'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Puntos: ${state.route.length}',
              key: const Key('tracker_points_label'),
            ),
            const SizedBox(height: 32),
            if (!isTracking)
              FilledButton.icon(
                key: const Key('tracker_start_button'),
                onPressed: () =>
                    ref.read(trackerNotifierProvider.notifier).startTracking(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar'),
              )
            else
              FilledButton.icon(
                key: const Key('tracker_stop_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => _onStop(context, ref),
                icon: const Icon(Icons.stop),
                label: const Text('Detener y guardar'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onStop(BuildContext context, WidgetRef ref) async {
    // TODO(Wave3): replace with actual userId from authNotifierProvider
    const userId = 'current-user';
    final logId = DateTime.now().microsecondsSinceEpoch.toString();

    final log = ref.read(trackerNotifierProvider.notifier).stopTracking(
          userId: userId,
          logId: logId,
        );

    if (log == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('tracker_too_short_snack'),
            content: Text('Recorrido demasiado corto para guardar.'),
          ),
        );
      }
      return;
    }

    try {
      final repo = ref.read(mileageRepositoryProvider);
      await repo.addLog(log);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('tracker_saved_snack'),
            content: Text(
              'Recorrido guardado: ${log.valueKm.toStringAsFixed(1)} km',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('tracker_error_snack'),
            content: Text('Error al guardar recorrido: $e'),
          ),
        );
      }
    }
  }
}
