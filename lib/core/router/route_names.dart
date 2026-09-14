// route_names.dart
//
// Centralized route path constants (AD-H2-5).
//
// All path strings are defined here once — no magic strings scattered across
// the codebase. GoRouter routes and redirect callbacks both reference these.

/// Compile-time route path constants for [AppRouter].
abstract final class RouteNames {
  /// Splash screen shown while the session state is still resolving.
  static const String splash = '/';

  /// Public auth routes.
  static const String login = '/login';
  static const String register = '/register';

  /// Protected routes — require an authenticated session.
  static const String dashboard = '/dashboard';

  /// Mileage logs list.
  static const String mileage = '/mileage';

  /// Maintenance reminders list.
  static const String maintenance = '/maintenance';

  /// Service records list.
  static const String services = '/services';

  /// Km projections (1M / 6M / 1Y charts).
  static const String projections = '/projections';

  /// GPS tracker (foreground start/stop).
  static const String tracker = '/tracker';

  /// App settings (theme toggle, export/import).
  static const String settings = '/settings';
}
