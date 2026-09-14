typedef ExportJsonMap = Map<String, dynamic>;

/// Current canonical export/import schema version.
const kCurrentExportSchemaVersion = 2;

/// Migrates an export/import payload from one schema version to another.
abstract interface class ExportSchemaMigrator {
  int get fromVersion;
  int get toVersion;

  ExportJsonMap migrate(ExportJsonMap payload);
}

/// Registry that resolves and executes chained schema migrations.
final class ExportSchemaMigratorRegistry {
  ExportSchemaMigratorRegistry(List<ExportSchemaMigrator> migrators)
      : _migratorsByFromVersion = {
          for (final migrator in migrators) migrator.fromVersion: migrator,
        };

  final Map<int, ExportSchemaMigrator> _migratorsByFromVersion;

  static final ExportSchemaMigratorRegistry defaultRegistry =
      ExportSchemaMigratorRegistry([
    _LegacyV1ToCurrentMigrator(),
  ]);

  ExportJsonMap migrateToCurrent(ExportJsonMap payload) {
    var version = _detectVersion(payload);
    var working = Map<String, dynamic>.from(payload);

    while (version < kCurrentExportSchemaVersion) {
      final migrator = _migratorsByFromVersion[version];
      if (migrator == null) {
        throw FormatException('No migrator available for schema version $version');
      }
      working = migrator.migrate(working);
      version = migrator.toVersion;
    }

    if (version > kCurrentExportSchemaVersion) {
      throw FormatException(
        'Unsupported schema version $version. Current: $kCurrentExportSchemaVersion',
      );
    }

    return working;
  }

  static int _detectVersion(ExportJsonMap payload) {
    final raw = payload['schemaVersion'] ?? payload['schema_version'];
    return (raw as num?)?.toInt() ?? 1;
  }
}

final class _LegacyV1ToCurrentMigrator implements ExportSchemaMigrator {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => kCurrentExportSchemaVersion;

  @override
  ExportJsonMap migrate(ExportJsonMap payload) {
    final exportedAt = payload['exportedAt'] ?? payload['exported_at'];
    final mileage = payload['mileage'] ?? payload['mileage_logs'] ?? const [];
    final reminders =
        payload['reminders'] ?? payload['maintenance_reminders'] ?? const [];
    final services = payload['services'] ?? payload['service_records'] ?? const [];
    final settings = payload['settings'] ?? payload['vehicle_settings'];

    return {
      'schemaVersion': kCurrentExportSchemaVersion,
      if (exportedAt != null) 'exportedAt': exportedAt,
      'mileage': List<Map<String, dynamic>>.from(
        (mileage as List).map((e) => Map<String, dynamic>.from(e as Map)),
      ),
      'reminders': List<Map<String, dynamic>>.from(
        (reminders as List).map((e) => Map<String, dynamic>.from(e as Map)),
      ),
      'services': List<Map<String, dynamic>>.from(
        (services as List).map((e) => Map<String, dynamic>.from(e as Map)),
      ),
      if (settings is Map)
        'settings': Map<String, dynamic>.from(settings),
    };
  }
}
