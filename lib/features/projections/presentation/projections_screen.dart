// projections_screen.dart
//
// Km projection screen — shows 1M / 6M / 1Y area charts.
//
// Design decisions:
//   - ConsumerWidget reads projectionsProvider(params) for each window.
//   - No business logic in widget — all calculation is in ProjectionCalculator.
//   - Tab-based window selector (1M / 6M / 1Y).
//   - Placeholder userId until auth context is wired in Wave 3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/projections/domain/projection_point.dart';
import 'package:mi_changan/features/projections/domain/projection_provider.dart';

/// Projection windows available in the UI.
enum _Window {
  oneMonth(1, '1M'),
  sixMonths(6, '6M'),
  oneYear(12, '1Y');

  const _Window(this.months, this.label);
  final int months;
  final String label;
}

/// Screen showing km projection charts for 1M / 6M / 1Y windows.
class ProjectionsScreen extends ConsumerStatefulWidget {
  const ProjectionsScreen({super.key});

  @override
  ConsumerState<ProjectionsScreen> createState() => _ProjectionsScreenState();
}

class _ProjectionsScreenState extends ConsumerState<ProjectionsScreen> {
  _Window _selected = _Window.sixMonths;

  @override
  Widget build(BuildContext context) {
    // TODO(Wave3): replace with actual userId from authNotifierProvider
    const userId = 'current-user';

    final params = ProjectionsParams(userId: userId, months: _selected.months);
    final asyncPoints = ref.watch(projectionsProvider(params));

    return Scaffold(
      key: const Key('projections_screen'),
      appBar: AppBar(title: const Text('Proyecciones')),
      body: Column(
        children: [
          _WindowSelector(
            selected: _selected,
            onChanged: (w) => setState(() => _selected = w),
          ),
          Expanded(
            child: asyncPoints.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error al calcular proyecciones: $e',
                  key: const Key('projections_error'),
                ),
              ),
              data: (points) => points.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin datos suficientes para proyectar.',
                        key: Key('projections_empty'),
                      ),
                    )
                  : _ProjectionChart(
                      key: const Key('projections_chart'),
                      points: points,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Window selector ───────────────────────────────────────────────────────

class _WindowSelector extends StatelessWidget {
  const _WindowSelector({
    required this.selected,
    required this.onChanged,
  });

  final _Window selected;
  final ValueChanged<_Window> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SegmentedButton<_Window>(
        key: const Key('projections_window_selector'),
        segments: _Window.values
            .map(
              (w) => ButtonSegment<_Window>(value: w, label: Text(w.label)),
            )
            .toList(),
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

// ── Projection chart ──────────────────────────────────────────────────────

/// Simple bar-based projection chart using Material BarCharts.
/// Full fl_chart integration is deferred to Wave 4 polish.
class _ProjectionChart extends StatelessWidget {
  const _ProjectionChart({super.key, required this.points});

  final List<ProjectionPoint> points;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('projections_list'),
      padding: const EdgeInsets.all(16),
      itemCount: points.length,
      itemBuilder: (context, index) {
        final point = points[index];
        final label =
            '${point.month.year}-${point.month.month.toString().padLeft(2, '0')}';
        return ListTile(
          key: Key('projection_item_$index'),
          leading: const Icon(Icons.trending_up),
          title: Text(label),
          trailing: Text(
            '${point.estimatedKm.toStringAsFixed(0)} km',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      },
    );
  }
}
