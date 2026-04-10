// projections_screen.dart
//
// Km projection screen — gráfico de línea + calculadoras + proyecciones rápidas.
//
// Design decisions:
//   - ConsumerStatefulWidget con TabBar: "Gráfico" y "Calculadoras".
//   - Tab Gráfico: cards rápidas 1M/3M/6M + LineChart (fl_chart) 12 meses +
//     lista detallada mensual.
//   - Tab Calculadoras: dos calculadoras basadas en ProjectionCalculator:
//       1. ¿Cuándo llegaré a X km? (dateToReachKm)
//       2. ¿Cuántos km tendré en fecha Y? (kmAtDate)
//   - Toda la lógica en ProjectionCalculator — widget solo presenta.
//   - userId from currentUserIdProvider (null-safe, router redirige a /login).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/projections/domain/projection_calculator.dart';
import 'package:mi_changan/features/projections/domain/projection_point.dart';
import 'package:mi_changan/features/projections/domain/projection_provider.dart';

// ── Quick-window enum (cards 1M / 3M / 6M) ───────────────────────────────────

enum _QuickWindow {
  oneMonth(1, '1 mes'),
  threeMonths(3, '3 meses'),
  sixMonths(6, '6 meses');

  const _QuickWindow(this.months, this.label);
  final int months;
  final String label;
}

const _kChartMonths = 12;

// ── Root screen ───────────────────────────────────────────────────────────────

/// Screen showing km projection chart + calculators.
class ProjectionsScreen extends ConsumerStatefulWidget {
  const ProjectionsScreen({super.key});

  @override
  ConsumerState<ProjectionsScreen> createState() => _ProjectionsScreenState();
}

class _ProjectionsScreenState extends ConsumerState<ProjectionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    // No session yet — router will redirect; show spinner meanwhile.
    if (userId == null) {
      return const Scaffold(
        key: Key('projections_screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final chartParams =
        ProjectionsParams(userId: userId, months: _kChartMonths);
    final asyncChartPoints = ref.watch(projectionsProvider(chartParams));

    return Scaffold(
      key: const Key('projections_screen'),
      appBar: AppBar(
        title: const Text('Proyecciones'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(key: Key('projections_tab_chart'), text: 'Gráfico'),
            Tab(key: Key('projections_tab_calc'), text: 'Calculadoras'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: chart + quick cards ──────────────────────────────────
          asyncChartPoints.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text(
                'No se pudieron calcular las proyecciones. Intentá de nuevo.',
                key: Key('projections_error'),
                textAlign: TextAlign.center,
              ),
            ),
            data: (model) => model.points.isEmpty
                ? const Center(
                    child: Text(
                      'Sin datos suficientes para proyectar.\n'
                      'Agregá al menos 2 registros de odómetro.',
                      key: Key('projections_empty'),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _ChartTab(
                    key: const Key('projections_chart_tab'),
                    points: model.points,
                    userId: userId,
                  ),
          ),

          // ── Tab 2: calculators ──────────────────────────────────────────
          _CalculatorsTab(
            key: const Key('projections_calculators_tab'),
            userId: userId,
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Chart + quick projection cards ─────────────────────────────────────

class _ChartTab extends ConsumerWidget {
  const _ChartTab({
    super.key,
    required this.points,
    required this.userId,
  });

  final List<ProjectionPoint> points;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Quick summary cards ────────────────────────────────────────
          const _SectionTitle(
            'Proyecciones rápidas',
            key: Key('projections_quick_section_title'),
          ),
          const SizedBox(height: 8),
          _QuickProjectionCards(userId: userId),
          const SizedBox(height: 24),

          // ── Line chart ─────────────────────────────────────────────────
          const _SectionTitle(
            'Proyección 12 meses',
            key: Key('projections_chart_section_title'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: _ProjectionLineChart(
              key: const Key('projections_chart'),
              points: points,
            ),
          ),
          const SizedBox(height: 16),

          // ── Detail list ────────────────────────────────────────────────
          const _SectionTitle(
            'Detalle mensual',
            key: Key('projections_detail_section_title'),
          ),
          const SizedBox(height: 8),
          _ProjectionList(
            key: const Key('projections_list'),
            points: points,
          ),
        ],
      ),
    );
  }
}

// ── Quick projection summary cards (1M / 3M / 6M) ────────────────────────────

class _QuickProjectionCards extends ConsumerWidget {
  const _QuickProjectionCards({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: _QuickWindow.values.map((w) {
        final params = ProjectionsParams(userId: userId, months: w.months);
        final async = ref.watch(projectionsProvider(params));
        final lastPoint = async.valueOrNull?.points.lastOrNull;

        return Expanded(
          child: Card(
            key: Key('projections_quick_card_${w.months}'),
            margin: const EdgeInsets.only(right: 8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    w.label,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  async.when(
                    loading: () => const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) =>
                        const Icon(Icons.error_outline, size: 16),
                    data: (_) => Text(
                      lastPoint != null
                          ? '${lastPoint.estimatedKm.toStringAsFixed(0)} km'
                          : '—',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Line chart ────────────────────────────────────────────────────────────────

class _ProjectionLineChart extends StatelessWidget {
  const _ProjectionLineChart({super.key, required this.points});

  final List<ProjectionPoint> points;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final spots = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.estimatedKm))
        .toList();

    final minY = spots.isEmpty ? 0.0 : spots.first.y * 0.95;
    final maxY = spots.isEmpty ? 1000.0 : spots.last.y * 1.05;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 58,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${(value / 1000).toStringAsFixed(0)}k',
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                final month = points[idx].month;
                return Text(
                  '${month.month.toString().padLeft(2, '0')}/'
                  '${month.year.toString().substring(2)}',
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: colorScheme.primary,
                strokeColor: colorScheme.surface,
                strokeWidth: 1.5,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final idx = s.x.toInt();
              if (idx < 0 || idx >= points.length) return null;
              final point = points[idx];
              final label =
                  '${point.month.year}-${point.month.month.toString().padLeft(2, '0')}';
              return LineTooltipItem(
                '$label\n${point.estimatedKm.toStringAsFixed(0)} km',
                TextStyle(color: colorScheme.onPrimary, fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Detail list ───────────────────────────────────────────────────────────────

class _ProjectionList extends StatelessWidget {
  const _ProjectionList({super.key, required this.points});

  final List<ProjectionPoint> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: points.asMap().entries.map((e) {
        final point = e.value;
        final label =
            '${point.month.year}-${point.month.month.toString().padLeft(2, '0')}';
        return ListTile(
          key: Key('projection_item_${e.key}'),
          dense: true,
          leading: const Icon(Icons.trending_up, size: 18),
          title: Text(label),
          trailing: Text(
            '${point.estimatedKm.toStringAsFixed(0)} km',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );
  }
}

// ── Tab 2: Calculators ────────────────────────────────────────────────────────

class _CalculatorsTab extends ConsumerStatefulWidget {
  const _CalculatorsTab({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<_CalculatorsTab> createState() => _CalculatorsTabState();
}

class _CalculatorsTabState extends ConsumerState<_CalculatorsTab> {
  // Calc 1 — when will I reach X km?
  final _targetKmCtrl = TextEditingController();
  String? _calc1Result;

  // Calc 2 — how many km will I have at date Y?
  DateTime? _targetDate;
  String? _calc2Result;

  @override
  void dispose() {
    _targetKmCtrl.dispose();
    super.dispose();
  }

  void _runCalc1(List<MileageLog> logs) {
    final target = double.tryParse(_targetKmCtrl.text.trim());
    if (target == null) {
      setState(
          () => _calc1Result = 'Ingresá un número válido de kilómetros.');
      return;
    }
    final result = ProjectionCalculator.dateToReachKm(
      logs: logs,
      targetKm: target,
      from: DateTime.now(),
    );
    if (result == null) {
      setState(() => _calc1Result =
          'Sin datos suficientes o el odómetro ya supera esa marca.');
    } else {
      setState(() =>
          _calc1Result = 'Estimado: ${DateFormat('dd/MM/yyyy').format(result)}');
    }
  }

  void _runCalc2(List<MileageLog> logs) {
    if (_targetDate == null) {
      setState(() => _calc2Result = 'Seleccioná una fecha futura.');
      return;
    }
    final result = ProjectionCalculator.kmAtDate(
      logs: logs,
      targetDate: _targetDate!,
      from: DateTime.now(),
    );
    if (result == null) {
      setState(() =>
          _calc2Result = 'Sin datos suficientes o la fecha es pasada.');
    } else {
      setState(
          () => _calc2Result = 'Estimado: ${result.toStringAsFixed(0)} km');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
        _calc2Result = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mileageRepositoryProvider);

    return FutureBuilder<List<MileageLog>>(
      future: repo.fetchLogs(userId: widget.userId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text(
              'No se pudieron cargar los datos.',
              key: Key('calculators_error'),
            ),
          );
        }
        final logs = snap.data ?? const [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Calc 1 ─────────────────────────────────────────────────
              const _SectionTitle(
                '¿Cuándo llegaré a X km?',
                key: Key('calc1_section_title'),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('calc1_target_km_field'),
                      controller: _targetKmCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kilómetros objetivo',
                        suffixText: 'km',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const Key('calc1_calculate_button'),
                    onPressed: () => _runCalc1(logs),
                    child: const Text('Calcular'),
                  ),
                ],
              ),
              if (_calc1Result != null) ...[
                const SizedBox(height: 12),
                _ResultCard(
                  key: const Key('calc1_result'),
                  text: _calc1Result!,
                ),
              ],

              const SizedBox(height: 32),

              // ── Calc 2 ─────────────────────────────────────────────────
              const _SectionTitle(
                '¿Cuántos km tendré en fecha Y?',
                key: Key('calc2_section_title'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('calc2_date_picker_button'),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _targetDate != null
                            ? DateFormat('dd/MM/yyyy').format(_targetDate!)
                            : 'Elegir fecha',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const Key('calc2_calculate_button'),
                    onPressed: () => _runCalc2(logs),
                    child: const Text('Calcular'),
                  ),
                ],
              ),
              if (_calc2Result != null) ...[
                const SizedBox(height: 12),
                _ResultCard(
                  key: const Key('calc2_result'),
                  text: _calc2Result!,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: cs.onSecondaryContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
