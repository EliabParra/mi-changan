import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/providers/production_overrides.dart';
import 'package:mi_changan/core/sync/data/sync_providers.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:mi_changan/features/maintenance/data/maintenance_providers.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/mileage/data/mileage_providers.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/services/data/service_providers.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/services/domain/service_repository.dart';
import 'package:mi_changan/features/tracker/data/real_device_location_gateway.dart';
import 'package:mi_changan/features/tracker/data/device_location_service_provider.dart';

void main() {
  test('production overrides wire offline-first repositories for writes', () {
    final container = ProviderContainer(
      overrides: [
        ...productionOverrides,
        supabaseMileageRepositoryProvider.overrideWithValue(_FakeMileageRemote()),
        supabaseMaintenanceRepositoryProvider
            .overrideWithValue(_FakeMaintenanceRemote()),
        supabaseServiceRepositoryProvider.overrideWithValue(_FakeServiceRemote()),
        syncOutboxRepositoryProvider.overrideWithValue(_FakeOutbox()),
      ],
    );
    addTearDown(container.dispose);

    final mileage = container.read(mileageRepositoryProvider);
    final maintenance = container.read(maintenanceRepositoryProvider);
    final service = container.read(serviceRepositoryProvider);

    expect(mileage.runtimeType.toString(), 'OfflineFirstMileageRepository');
    expect(
      maintenance.runtimeType.toString(),
      'OfflineFirstMaintenanceRepository',
    );
    expect(service.runtimeType.toString(), 'OfflineFirstServiceRepository');
  });

  test('production overrides wire real GPS gateway for tracker location service', () {
    final container = ProviderContainer(overrides: productionOverrides);
    addTearDown(container.dispose);

    final locationService = container.read(deviceLocationServiceProvider);

    expect(locationService.gateway, isA<RealDeviceLocationGateway>());
  });
}

class _FakeOutbox implements SyncOutboxRepository {
  @override
  Future<void> enqueue(SyncOutboxEvent event) async {}

  @override
  Future<void> markConflict(String eventId, SyncConflictRecord conflict) async {}

  @override
  Future<void> markFailed(
    String eventId, {
    required String reason,
    DateTime? nextRetryAt,
  }) async {}

  @override
  Future<void> markSynced(String eventId, {required DateTime syncedAt}) async {}

  @override
  Future<List<SyncOutboxEvent>> pullReady({required int limit}) async => const [];
}

class _FakeMileageRemote implements MileageRepository {
  @override
  Future<void> addLog(MileageLog log) async {}

  @override
  Future<void> deleteLog(String logId) async {}

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async => const [];
}

class _FakeMaintenanceRemote implements MaintenanceRepository {
  @override
  Future<void> addReminder(MaintenanceReminder reminder) async {}

  @override
  Future<void> deleteReminder(String reminderId) async {}

  @override
  Future<List<MaintenanceReminder>> fetchReminders({required String userId}) async =>
      const [];

  @override
  Future<void> updateReminder(MaintenanceReminder reminder) async {}
}

class _FakeServiceRemote implements ServiceRepository {
  @override
  Future<void> addRecord(ServiceRecord record) async {}

  @override
  Future<void> deleteRecord(String recordId) async {}

  @override
  Future<List<ServiceRecord>> fetchRecords({required String userId}) async => const [];
}
