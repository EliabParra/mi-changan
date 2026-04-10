// production_overrides.dart
//
// Binds abstract repository providers to their concrete Supabase implementations
// for production builds.
//
// Design decisions:
//   - All abstract repository providers use UnimplementedError by default
//     (fail-fast in tests that forget to override).
//   - This list is passed to ProviderScope in main.dart.
//   - Tests supply their own fakes without touching this file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/maintenance/data/maintenance_providers.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';
import 'package:mi_changan/features/mileage/data/mileage_providers.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/services/data/service_providers.dart';
import 'package:mi_changan/features/services/domain/service_repository.dart';
import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/data/device_location_service_provider.dart';
import 'package:mi_changan/features/tracker/data/local_tracking_session_repository.dart';
import 'package:mi_changan/features/tracker/data/real_device_location_gateway.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_repository_provider.dart';

/// Production Riverpod overrides that bind abstract repos to Supabase impls.
///
/// Pass this list to [ProviderScope.overrides] in [main.dart].
final List<Override> productionOverrides = [
  // Mileage
  mileageRepositoryProvider
      .overrideWith((ref) => ref.watch(offlineFirstMileageRepositoryProvider)),

  // Maintenance
  maintenanceRepositoryProvider
      .overrideWith(
          (ref) => ref.watch(offlineFirstMaintenanceRepositoryProvider)),

  // Services
  serviceRepositoryProvider
      .overrideWith((ref) => ref.watch(offlineFirstServiceRepositoryProvider)),

  // Tracker
  trackingSessionRepositoryProvider
      .overrideWith((_) => LocalTrackingSessionRepository()),
  deviceLocationServiceProvider.overrideWith(
    (_) => DeviceLocationService(gateway: RealDeviceLocationGateway()),
  ),
];
