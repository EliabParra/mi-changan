// mileage_notifier_provider.dart
//
// Riverpod provider declaration for MileageNotifier.
//
// Separated from the notifier so router / other providers can import
// only the provider reference without loading the full notifier.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_notifier.dart';

/// The application-wide mileage logs provider, keyed by userId.
///
/// Exposes [AsyncValue<List<MileageLog>>].
final mileageNotifierProvider =
    AsyncNotifierProvider.family<MileageNotifier, List<MileageLog>, String>(
  MileageNotifier.new,
);
