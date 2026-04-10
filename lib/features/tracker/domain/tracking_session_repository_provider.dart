import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_changan/features/tracker/data/local_tracking_session_repository.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_repository.dart';

final trackingSessionRepositoryProvider =
    Provider<TrackingSessionRepository>((ref) {
  return LocalTrackingSessionRepository();
});
