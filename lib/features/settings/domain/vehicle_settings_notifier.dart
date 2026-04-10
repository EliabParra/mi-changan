// vehicle_settings_notifier.dart
//
// Domain-layer AsyncNotifier for vehicle-specific settings persisted in
// SharedPreferences.
//
// Design decisions:
//   - AsyncNotifier<VehicleSettings> — async because SharedPreferences read
//     is async on startup.
//   - VehicleSettings is an immutable value object.
//   - Keys use a 'vehicle_' prefix to avoid collisions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Immutable value object for vehicle configuration settings.
class VehicleSettings {
  const VehicleSettings({
    this.initialKm,
    this.purchaseDate,
    this.lastTireChangeKm,
    this.nextServiceKm,
  });

  /// Odometer reading when the vehicle was bought.
  final double? initialKm;

  /// Date the vehicle was purchased.
  final DateTime? purchaseDate;

  /// Odometer reading at the last tire change.
  final double? lastTireChangeKm;

  /// Odometer reading at which the next service is scheduled.
  /// Used by the dashboard to show the service alert card.
  final double? nextServiceKm;

  VehicleSettings copyWith({
    double? initialKm,
    DateTime? purchaseDate,
    double? lastTireChangeKm,
    double? nextServiceKm,
    bool clearInitialKm = false,
    bool clearPurchaseDate = false,
    bool clearTireKm = false,
    bool clearNextServiceKm = false,
  }) =>
      VehicleSettings(
        initialKm: clearInitialKm ? null : (initialKm ?? this.initialKm),
        purchaseDate:
            clearPurchaseDate ? null : (purchaseDate ?? this.purchaseDate),
        lastTireChangeKm:
            clearTireKm ? null : (lastTireChangeKm ?? this.lastTireChangeKm),
        nextServiceKm: clearNextServiceKm
            ? null
            : (nextServiceKm ?? this.nextServiceKm),
      );
}

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kInitialKm = 'vehicle_initial_km';
const _kPurchaseDate = 'vehicle_purchase_date';
const _kLastTireKm = 'vehicle_last_tire_km';
const _kNextServiceKm = 'vehicle_next_service_km';

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Manages vehicle configuration settings persisted in SharedPreferences.
class VehicleSettingsNotifier extends AsyncNotifier<VehicleSettings> {
  @override
  Future<VehicleSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final initialKm = prefs.getDouble(_kInitialKm);
    final purchaseDateMs = prefs.getInt(_kPurchaseDate);
    final lastTireKm = prefs.getDouble(_kLastTireKm);
    final nextServiceKm = prefs.getDouble(_kNextServiceKm);

    return VehicleSettings(
      initialKm: initialKm,
      purchaseDate: purchaseDateMs != null
          ? DateTime.fromMillisecondsSinceEpoch(purchaseDateMs)
          : null,
      lastTireChangeKm: lastTireKm,
      nextServiceKm: nextServiceKm,
    );
  }

  /// Set and persist the initial odometer reading.
  Future<void> setInitialKm(double km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kInitialKm, km);
    final current = state.valueOrNull ?? const VehicleSettings();
    state = AsyncData(current.copyWith(initialKm: km));
  }

  /// Set and persist the vehicle purchase date.
  Future<void> setPurchaseDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPurchaseDate, date.millisecondsSinceEpoch);
    final current = state.valueOrNull ?? const VehicleSettings();
    state = AsyncData(current.copyWith(purchaseDate: date));
  }

  /// Set and persist the odometer reading at the last tire change.
  Future<void> setLastTireChangeKm(double km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLastTireKm, km);
    final current = state.valueOrNull ?? const VehicleSettings();
    state = AsyncData(current.copyWith(lastTireChangeKm: km));
  }

  /// Set and persist the km at which the next service is scheduled.
  Future<void> setNextServiceKm(double km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kNextServiceKm, km);
    final current = state.valueOrNull ?? const VehicleSettings();
    state = AsyncData(current.copyWith(nextServiceKm: km));
  }

  /// Clear the next service km setting.
  Future<void> clearNextServiceKm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNextServiceKm);
    final current = state.valueOrNull ?? const VehicleSettings();
    state = AsyncData(current.copyWith(clearNextServiceKm: true));
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Application-wide vehicle settings provider.
final vehicleSettingsProvider =
    AsyncNotifierProvider<VehicleSettingsNotifier, VehicleSettings>(
  VehicleSettingsNotifier.new,
);
