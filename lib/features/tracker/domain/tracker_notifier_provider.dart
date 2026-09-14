// tracker_notifier_provider.dart
//
// Riverpod provider for TrackerNotifier.
//
// Design decisions:
//   - Global (not family) — only one tracker session at a time.
//   - Tests override with a fresh ProviderContainer (no override needed
//     since TrackerNotifier has no external dependencies).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/tracker/domain/tracker_notifier.dart';
import 'package:mi_changan/features/tracker/domain/tracker_state.dart';

/// Global provider for the foreground GPS tracking session.
final trackerNotifierProvider =
    NotifierProvider<TrackerNotifier, TrackerState>(TrackerNotifier.new);
