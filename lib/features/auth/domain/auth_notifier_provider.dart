// auth_notifier_provider.dart
//
// Riverpod provider declaration for AuthNotifier (AD-H2-3).
//
// Kept in a separate file so:
//   - lib/core/router/app_router.dart can import just the provider
//     without pulling in the full notifier implementation.
//   - Tests can override [authNotifierProvider] independently of [authRepositoryProvider].

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/auth/domain/auth_notifier.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';

/// The application-wide auth state provider.
///
/// Exposes [AsyncValue<AuthStatus>]:
///   - [AsyncLoading] — app started, waiting for session hydration.
///   - [AsyncData(AuthStatus.authenticated)] — valid session present.
///   - [AsyncData(AuthStatus.unauthenticated)] — no session.
///   - [AsyncError] — an auth operation failed.
///
/// GoRouter's [refreshListenable] watches this provider to trigger
/// route re-evaluation whenever auth state changes.
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthStatus>(AuthNotifier.new);
