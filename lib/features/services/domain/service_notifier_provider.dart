// service_notifier_provider.dart
//
// Riverpod provider declaration for ServiceNotifier.
//
// Separated from the notifier so router / other providers can import
// only the provider reference without loading the full notifier.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/services/domain/service_notifier.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';

/// The application-wide service records provider, keyed by userId.
///
/// Exposes [AsyncValue<List<ServiceRecord>>].
final serviceNotifierProvider =
    AsyncNotifierProvider.family<ServiceNotifier, List<ServiceRecord>, String>(
  ServiceNotifier.new,
);
