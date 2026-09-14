// dashboard_screen.dart
//
// Dashboard — main overview screen shown in the AppShell.
//
// Design decisions:
//   - DashboardBody is the widget used inside AppShell's IndexedStack.
//   - DashboardScreen (full Scaffold) kept for deep-link / standalone use.
//   - Reads dashboardMetricsProvider(userId) for all aggregate data.
//   - Reads maintenanceNotifierProvider(userId) for next-service alert.
//   - userId comes from currentUserIdProvider (Supabase session — null-safe).
//   - If userId is null DashboardBody shows a spinner while the router
//     redirects unauthenticated users to /login.
//   - Key('dashboard_screen') is REQUIRED — existing router tests rely on it.
//   - Error messages are friendly Spanish — no raw exceptions shown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/core/router/route_names.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/dashboard/domain/dashboard_metrics.dart';
import 'package:mi_changan/features/dashboard/domain/dashboard_provider.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_notifier_provider.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';

/// Full dashboard screen (standalone / for router tests).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('dashboard_screen'),
      appBar: AppBar(
        title: const Text('Mi Changan'),
        actions: [
          IconButton(
            key: const Key('dashboard_logout_button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: const DashboardBody(),
    );
  }
}

/// Dashboard body widget — used inside AppShell's IndexedStack.
class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // No session yet — router will redirect to /login; show spinner meanwhile.
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final asyncMetrics = ref.watch(dashboardMetricsProvider(userId));
    final asyncReminders = ref.watch(maintenanceNotifierProvider(userId));

    // Extract first upcoming/due reminder for service alert
    final MaintenanceReminder? nearestReminder = asyncReminders.valueOrNull
        ?.where((r) =>
            r.status == ReminderStatus.due || r.status == ReminderStatus.overdue)
        .fold<MaintenanceReminder?>(null, (prev, curr) {
      if (prev == null) return curr;
      final prevRemaining = prev.kmRemaining ?? double.infinity;
      final currRemaining = curr.kmRemaining ?? double.infinity;
      return currRemaining < prevRemaining ? curr : prev;
    });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardMetricsProvider(userId));
        ref.invalidate(maintenanceNotifierProvider(userId));
      },
      child: asyncMetrics.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text(
            key: Key('dashboard_error'),
            'No se pudieron cargar los datos. Tirá hacia abajo para reintentar.',
            textAlign: TextAlign.center,
          ),
        ),
        data: (metrics) => _DashboardContent(
          metrics: metrics,
          nearestReminder: nearestReminder,
        ),
      ),
    );
  }
}

// ── Dashboard content ─────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.metrics,
    this.nearestReminder,
  });

  final DashboardMetrics metrics;
  final MaintenanceReminder? nearestReminder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numFmt = NumberFormat('#,##0', 'es');
    final decFmt = NumberFormat('#,##0.0', 'es');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Service alert banner ───────────────────────────────────────────
        if (nearestReminder != null) ...[
          _ServiceAlertBanner(reminder: nearestReminder!),
          const SizedBox(height: 16),
        ],

        // ── Odometer card (km actual) ──────────────────────────────────────
        _MetricCard(
          key: const Key('dashboard_total_km_card'),
          icon: Icons.speed,
          title: 'Odómetro actual',
          value: '${numFmt.format(metrics.totalKm)} km',
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),

        // ── Total accumulated km (sum of all distance logs) ────────────────
        if (metrics.accumulatedKm > 0) ...[
          _MetricCard(
            key: const Key('dashboard_accumulated_km_card'),
            icon: Icons.route,
            title: 'Total km recorridos',
            value: '${numFmt.format(metrics.accumulatedKm)} km',
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
        ],

        // ── Weekly summary card ────────────────────────────────────────────
        _WeeklySummaryCard(
          key: const Key('dashboard_weekly_card'),
          weeklyKm: metrics.weeklyKm,
          avgKmPerDay: metrics.avgKmPerDay,
        ),
        const SizedBox(height: 12),

        // ── Stats row ──────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                key: const Key('dashboard_avg_day_card'),
                icon: Icons.calendar_today,
                title: 'Promedio / día',
                value: '${decFmt.format(metrics.avgKmPerDay)} km',
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                key: const Key('dashboard_avg_month_card'),
                icon: Icons.date_range,
                title: 'Promedio / mes',
                value: '${numFmt.format(metrics.avgKmPerMonth)} km',
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),

        // ── Next service card (if configured) ─────────────────────────────
        if (metrics.nextServiceKm != null) ...[
          const SizedBox(height: 12),
          _NextServiceCard(
            key: const Key('dashboard_next_service_card'),
            metrics: metrics,
          ),
        ],

        const SizedBox(height: 24),

        // ── Quick actions ──────────────────────────────────────────────────
        Text(
          'Acciones rápidas',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const _QuickActions(),
        const SizedBox(height: 24),

        // ── Empty state hint ───────────────────────────────────────────────
        if (metrics.totalKm == 0 && metrics.avgKmPerDay == 0)
          Card(
            key: const Key('dashboard_empty_hint'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Aún no hay registros de km.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agregá logs de odómetro en la pestaña "Km" para ver las métricas.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Quick actions row ─────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            key: const Key('quick_action_mileage'),
            icon: Icons.speed,
            label: 'Agregar km',
            onTap: () => context.go(RouteNames.mileage),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            key: const Key('quick_action_tracker'),
            icon: Icons.gps_fixed,
            label: 'Tracker GPS',
            onTap: () => context.go(RouteNames.tracker),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            key: const Key('quick_action_maintenance'),
            icon: Icons.build,
            label: 'Servicio',
            onTap: () => context.go(RouteNames.maintenance),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            key: const Key('quick_action_projections'),
            icon: Icons.trending_up,
            label: 'Proyecciones',
            onTap: () => context.go(RouteNames.projections),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Weekly summary card ───────────────────────────────────────────────────────

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({
    super.key,
    required this.weeklyKm,
    required this.avgKmPerDay,
  });

  final double weeklyKm;
  final double avgKmPerDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numFmt = NumberFormat('#,##0.0', 'es');

    // Compute expected weekly km from daily average for progress indicator
    final expected = avgKmPerDay * 7;
    final progress =
        (expected > 0) ? (weeklyKm / expected).clamp(0.0, 1.5) : 0.0;
    final isAboveAvg = expected > 0 && weeklyKm > expected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen semanal',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        weeklyKm > 0
                            ? '${numFmt.format(weeklyKm)} km esta semana'
                            : 'Sin registros esta semana',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAboveAvg)
                  Chip(
                    key: const Key('dashboard_weekly_above_avg_chip'),
                    label: const Text('↑ sobre promedio'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (expected > 0) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                key: const Key('dashboard_weekly_progress'),
                value: progress.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: isAboveAvg
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                'Esperado: ${numFmt.format(expected)} km'
                ' (${numFmt.format(avgKmPerDay)} km/día × 7)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Reusable metric card ──────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Next service card ─────────────────────────────────────────────────────────

class _NextServiceCard extends StatelessWidget {
  const _NextServiceCard({super.key, required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final isOverdue = metrics.isOverdue;
    final remaining = metrics.nextServiceAlertKm ?? 0;
    final color = isOverdue
        ? Theme.of(context).colorScheme.error
        : remaining <= 500
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;
    final numFmt = NumberFormat('#,##0', 'es');

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isOverdue ? Icons.warning_rounded : Icons.car_repair,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOverdue ? 'Servicio vencido' : 'Próximo servicio',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    isOverdue
                        ? 'Pasaste el km programado de servicio'
                        : remaining <= 500
                            ? '¡Solo quedan ${numFmt.format(remaining.abs())} km — programá tu servicio!'
                            : 'Quedan ${numFmt.format(remaining.abs())} km para el próximo servicio',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Service alert banner ──────────────────────────────────────────────────────

class _ServiceAlertBanner extends StatelessWidget {
  const _ServiceAlertBanner({required this.reminder});

  final MaintenanceReminder reminder;

  @override
  Widget build(BuildContext context) {
    final isOverdue = reminder.status == ReminderStatus.overdue;
    final numFmt = NumberFormat('#,##0', 'es');
    final color =
        isOverdue ? Theme.of(context).colorScheme.error : Colors.orange;

    return MaterialBanner(
      key: const Key('dashboard_service_alert_banner'),
      backgroundColor: color.withValues(alpha: 0.12),
      leading: Icon(Icons.warning_rounded, color: color),
      content: Text(
        isOverdue
            ? '${reminder.label}: servicio vencido'
            : '${reminder.label}: quedan ${numFmt.format(reminder.kmRemaining?.abs() ?? 0)} km',
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      actions: [
        TextButton(
          onPressed: () {},
          child: const Text('Ver'),
        ),
      ],
    );
  }
}
