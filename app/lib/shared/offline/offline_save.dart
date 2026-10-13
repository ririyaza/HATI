import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';

/// How a user-initiated save actually landed.
enum SaveOutcome {
  /// The server acknowledged the write.
  synced,

  /// Firestore accepted the write into its local cache and will upload it
  /// on its own once the device reconnects (even across an app restart).
  /// The UI already reflects it — listeners see local writes immediately.
  savedOffline,
}

/// Wraps Firestore writes so a save never leaves the user staring at a
/// spinner just because they're offline.
///
/// Firestore queues writes locally while offline, but the `Future` returned
/// by `set()`/`commit()` only completes once the *server* acknowledges it —
/// so `await ref.set(...)` offline hangs until the connection comes back,
/// and a sequence of awaited writes never even queues the second one.
/// [OfflineSave.run] instead builds every write into one atomic batch,
/// commits it, and returns as soon as it knows the outcome:
///
/// * offline → [SaveOutcome.savedOffline] immediately;
/// * online and acknowledged → [SaveOutcome.synced];
/// * online but no ack within [_ackTimeout] (flaky network) →
///   [SaveOutcome.savedOffline], the commit keeps going in the background;
/// * rejected (e.g. permission-denied) → throws, like a plain write.
abstract final class OfflineSave {
  static const _ackTimeout = Duration(seconds: 6);

  static Future<SaveOutcome> run(
    void Function(WriteBatch batch) build, {
    FirebaseFirestore? firestore,
  }) async {
    final batch = (firestore ?? FirebaseFirestore.instance).batch();
    build(batch);
    final commit = batch.commit();

    final connectivity = ConnectivityService.instance;
    if (!connectivity.isOnline) {
      _finishInBackground(commit);
      return SaveOutcome.savedOffline;
    }

    try {
      await commit.timeout(_ackTimeout);
      return SaveOutcome.synced;
    } on TimeoutException {
      _finishInBackground(commit);
      connectivity.reportNetworkFailure();
      return SaveOutcome.savedOffline;
    }
  }

  /// A queued commit that's later rejected by the server (security rules)
  /// has no screen left to report to — log it rather than leaving an
  /// unhandled async error.
  static void _finishInBackground(Future<void> commit) {
    unawaited(
      commit.catchError((Object e) {
        debugPrint('OfflineSave: queued write failed to sync: $e');
      }),
    );
  }
}
