// app_router.dart
//
// Centralized GoRouter configuration with auth guard (AD-H2-5).
//
// Design decisions:
//   - The router is created as a Riverpod Provider so it can read
//     [authNotifierProvider] and wire [refreshListenable].
//   - [buildAppRouter] is a pure factory used by tests — it accepts
//     a fixed [AsyncValue<AuthStatus>] and an initial location, removing
//     the need to mock Riverpod inside GoRouter itself.
//   - Redirect matrix (in [_guardRedirect]):
//       1. AsyncLoading  → redirect to '/' (splash — deterministic, no crash)
//       2. AsyncError    → redirect to '/login'
//       3. Unauthenticated + protected route → '/login'
//       4. Authenticated + public-only route → '/dashboard'
//       5. Otherwise → null (allow navigation)
//   - Real screens for /login, /register, /dashboard injected in Batch D.
//     Widget Keys in each real screen are compatible with Batch C test contracts.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mi_changan/core/router/route_names.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';
import 'package:mi_changan/features/auth/presentation/login_screen.dart';
import 'package:mi_changan/features/auth/presentation/register_screen.dart';
import 'package:mi_changan/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mi_changan/features/maintenance/presentation/maintenance_screen.dart';
import 'package:mi_changan/features/projections/presentation/projections_screen.dart';
import 'package:mi_changan/features/services/presentation/services_screen.dart';
import 'package:mi_changan/features/settings/presentation/settings_screen.dart';
import 'package:mi_changan/features/tracker/presentation/tracker_screen.dart';

// ── Public routes (no auth required) ─────────────────────────────────────────
const _publicRoutes = {RouteNames.login, RouteNames.register};

// ── Guard redirect logic (pure function — easy to test) ───────────────────────

/// Returns a redirect path or [null] (allow navigation).
///
/// [state] — current [GoRouterState] with the attempted location.
/// [authValue] — current auth state from [authNotifierProvider].
String? _guardRedirect(GoRouterState state, AsyncValue<AuthStatus> authValue) {
  final location = state.matchedLocation;

  return authValue.when(
    loading: () {
      // Session is still hydrating — show splash unless already there.
      if (location == RouteNames.splash) return null;
      return RouteNames.splash;
    },
    error: (_, __) {
      if (location == RouteNames.login) return null;
      return RouteNames.login;
    },
    data: (status) {
      final isAuthenticated = status == AuthStatus.authenticated;
      final isPublicRoute = _publicRoutes.contains(location);

      if (!isAuthenticated && !isPublicRoute) {
        // Protected route attempted without a session → force login
        return RouteNames.login;
      }
      if (isAuthenticated && isPublicRoute) {
        // Already authenticated — no need to show auth screens
        return RouteNames.dashboard;
      }
      // Authenticated on splash → go to dashboard
      if (isAuthenticated && location == RouteNames.splash) {
        return RouteNames.dashboard;
      }
      // Unauthenticated on splash → go to login
      if (!isAuthenticated && location == RouteNames.splash) {
        return RouteNames.login;
      }
      return null; // Allow navigation
    },
  );
}

// ── Riverpod router provider ──────────────────────────────────────────────────

/// Application-wide [GoRouter] provider.
///
/// Reads [authNotifierProvider] and wires [refreshListenable] so that every
/// auth state change triggers a route re-evaluation.
final appRouterProvider = Provider<GoRouter>((ref) {
  // RouterNotifier bridges Riverpod state changes → ChangeNotifier ticks
  // so GoRouter's refreshListenable re-runs the redirect callback.
  final routerNotifier = _RouterNotifier(ref);

  return GoRouter(
    refreshListenable: routerNotifier,
    initialLocation: RouteNames.splash,
    redirect: (context, state) {
      final authValue = ref.read(authNotifierProvider);
      return _guardRedirect(state, authValue);
    },
    routes: _routes,
  );
});

// ── Test-only factory ─────────────────────────────────────────────────────────

/// Creates a [GoRouter] with a fixed [authState] — for widget tests only.
///
/// This removes Riverpod from the router so tests can assert redirect behavior
/// with deterministic auth values without setting up a full ProviderScope.
GoRouter buildAppRouter({
  required AsyncValue<AuthStatus> authState,
  String initialLocation = RouteNames.login,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) => _guardRedirect(state, authState),
    routes: _routes,
  );
}

// ── Route table ───────────────────────────────────────────────────────────────

final List<RouteBase> _routes = [
  GoRoute(
    path: RouteNames.splash,
    name: 'splash',
    builder: (_, __) => const SplashScreen(),
  ),
  GoRoute(
    path: RouteNames.login,
    name: 'login',
    builder: (_, __) => const LoginScreen(),
  ),
  GoRoute(
    path: RouteNames.register,
    name: 'register',
    builder: (_, __) => const RegisterScreen(),
  ),
  GoRoute(
    path: RouteNames.dashboard,
    name: 'dashboard',
    builder: (_, __) => const DashboardScreen(),
  ),
  GoRoute(
    path: RouteNames.maintenance,
    name: 'maintenance',
    builder: (_, __) => const MaintenanceScreen(),
  ),
  GoRoute(
    path: RouteNames.services,
    name: 'services',
    builder: (_, __) => const ServicesScreen(),
  ),
  GoRoute(
    path: RouteNames.projections,
    name: 'projections',
    builder: (_, __) => const ProjectionsScreen(),
  ),
  GoRoute(
    path: RouteNames.tracker,
    name: 'tracker',
    builder: (_, __) => const TrackerScreen(),
  ),
  GoRoute(
    path: RouteNames.settings,
    name: 'settings',
    builder: (_, __) => const SettingsScreen(),
  ),
];

// ── RouterNotifier — bridges Riverpod → ChangeNotifier ───────────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    // Re-notify GoRouter whenever auth state changes
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

// ── Splash screen ─────────────────────────────────────────────────────────────

/// Splash screen shown while session hydrates on startup.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('splash_screen'),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
