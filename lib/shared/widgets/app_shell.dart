// app_shell.dart
//
// Application shell — provides persistent bottom navigation bar across all
// protected routes (Dashboard, Logs, Tracker, Mantenimiento, Servicios,
// Proyecciones, Ajustes).
//
// Design decisions:
//   - Integrated with GoRouter ShellRoute: AppShell receives the active
//     [child] widget from the router and renders it in the body area.
//   - Bottom NavigationBar uses context.go() — proper GoRouter navigation,
//     no imperative push/pop that would break deep links.
//   - Tab selection is derived from the current GoRouter location so back
//     button and deep links always highlight the correct tab.
//   - "Más" tab groups Servicios, Proyecciones and Ajustes as a secondary
//     navigation list for a clean 5-tab layout at MVP.
//   - Shell key is Key('app_shell') for widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mi_changan/core/router/route_names.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';

// ── Tab index ↔ route mapping ─────────────────────────────────────────────────

const _tabRoutes = [
  RouteNames.dashboard,
  RouteNames.mileage,
  RouteNames.tracker,
  RouteNames.maintenance,
  RouteNames.settings, // "Más" anchor: defaults to settings overview
];

int _locationToIndex(String location) {
  if (location.startsWith(RouteNames.mileage)) return 1;
  if (location.startsWith(RouteNames.tracker)) return 2;
  if (location.startsWith(RouteNames.maintenance)) return 3;
  if (location.startsWith(RouteNames.services)) return 4;
  if (location.startsWith(RouteNames.projections)) return 4;
  if (location.startsWith(RouteNames.settings)) return 4;
  return 0; // dashboard
}

/// Navigation destinations for the app shell.
const _destinations = [
  NavigationDestination(
    key: Key('nav_dashboard'),
    icon: Icon(Icons.dashboard_outlined),
    selectedIcon: Icon(Icons.dashboard),
    label: 'Inicio',
  ),
  NavigationDestination(
    key: Key('nav_mileage'),
    icon: Icon(Icons.speed_outlined),
    selectedIcon: Icon(Icons.speed),
    label: 'Km',
  ),
  NavigationDestination(
    key: Key('nav_tracker'),
    icon: Icon(Icons.gps_not_fixed),
    selectedIcon: Icon(Icons.gps_fixed),
    label: 'Tracker',
  ),
  NavigationDestination(
    key: Key('nav_maintenance'),
    icon: Icon(Icons.build_outlined),
    selectedIcon: Icon(Icons.build),
    label: 'Servicio',
  ),
  NavigationDestination(
    key: Key('nav_more'),
    icon: Icon(Icons.more_horiz),
    selectedIcon: Icon(Icons.more_horiz),
    label: 'Más',
  ),
];

/// App shell with persistent bottom navigation bar.
///
/// [child] is provided by GoRouter's ShellRoute — it contains the active
/// feature screen widget matched by the current route.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _locationToIndex(location);

    // "Más" tab: when tapped while already on index 4, show bottom sheet menu
    void onDestinationSelected(int index) {
      if (index == 4) {
        // Show "Más" menu as bottom sheet if already on a "más" route,
        // otherwise navigate to services as default entry point.
        _showMoreSheet(context, ref, location);
        return;
      }
      context.go(_tabRoutes[index]);
    }

    return Scaffold(
      key: const Key('app_shell'),
      body: child,
      bottomNavigationBar: NavigationBar(
        key: const Key('app_nav_bar'),
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: _destinations,
      ),
    );
  }
}

// ── "Más" bottom sheet ────────────────────────────────────────────────────────

void _showMoreSheet(BuildContext context, WidgetRef ref, String currentLocation) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MoreSheet(
      currentLocation: currentLocation,
      onNavigate: (route) {
        Navigator.of(ctx).pop();
        context.go(route);
      },
      onLogout: () async {
        Navigator.of(ctx).pop();
        await ref.read(authNotifierProvider.notifier).logout();
      },
    ),
  );
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.currentLocation,
    required this.onNavigate,
    required this.onLogout,
  });

  final String currentLocation;
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ─────────────────────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Navigation items ───────────────────────────────────────────
            _MoreItem(
              key: const Key('more_services_tile'),
              icon: Icons.car_repair,
              label: 'Servicios',
              subtitle: 'Historial de servicios realizados',
              selected: currentLocation.startsWith(RouteNames.services),
              onTap: () => onNavigate(RouteNames.services),
            ),
            _MoreItem(
              key: const Key('more_projections_tile'),
              icon: Icons.trending_up,
              label: 'Proyecciones',
              subtitle: 'Estimación de km futuros',
              selected: currentLocation.startsWith(RouteNames.projections),
              onTap: () => onNavigate(RouteNames.projections),
            ),
            _MoreItem(
              key: const Key('more_settings_tile'),
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              subtitle: 'Tema, datos y exportación',
              selected: currentLocation.startsWith(RouteNames.settings),
              onTap: () => onNavigate(RouteNames.settings),
            ),

            const Divider(indent: 16, endIndent: 16),

            // ── Logout ─────────────────────────────────────────────────────
            ListTile(
              key: const Key('shell_logout_button'),
              leading: Icon(
                Icons.logout,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Cerrar sesión',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : null;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: selected ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
