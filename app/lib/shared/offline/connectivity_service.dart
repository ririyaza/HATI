import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide "can we actually reach the internet right now?" signal.
///
/// `connectivity_plus` alone only reports whether a network *interface* is
/// up — a phone on campus Wi-Fi behind a captive portal, or on mobile data
/// with no load, still reports `wifi`/`mobile`. So every interface change is
/// confirmed with a real DNS lookup, and while offline the lookup is polled
/// so the app notices recovery even when the interface itself never changes.
///
/// Starts optimistic ([isOnline] = true) so nothing is blocked before the
/// first check finishes on launch.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  static const _probeHost = 'firestore.googleapis.com';
  static const _probeTimeout = Duration(seconds: 4);
  static const _offlinePollInterval = Duration(seconds: 15);

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlinePoll;
  Future<bool>? _inFlightCheck;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    if (_subscription != null) return;
    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
    try {
      _onChanged(await _connectivity.checkConnectivity());
    } catch (e) {
      debugPrint('ConnectivityService: initial check failed: $e');
    }
  }

  void _onChanged(List<ConnectivityResult> results) {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      _setOnline(false);
      return;
    }
    unawaited(checkNow());
  }

  /// Re-verifies reachability right now. Concurrent callers share one probe.
  Future<bool> checkNow() {
    return _inFlightCheck ??= _probe().then((online) {
      _setOnline(online);
      return online;
    }).whenComplete(() => _inFlightCheck = null);
  }

  /// For gating an action that can't work offline (an HTTP/AI call): returns
  /// immediately while online, and re-checks first while offline so a stale
  /// "offline" never blocks the user once their connection is actually back.
  Future<bool> ensureOnline() async => _isOnline || await checkNow();

  /// Call when a request fails at the network layer, so the rest of the app
  /// (banner, save feedback) learns about it without waiting for a poll.
  void reportNetworkFailure() => unawaited(checkNow());

  Future<bool> _probe() async {
    // dart:io lookups aren't available on web; the browser's own online
    // status (what connectivity_plus reports there) is the best signal.
    if (kIsWeb) {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    }
    try {
      final result = await InternetAddress.lookup(
        _probeHost,
      ).timeout(_probeTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  void setOnlineForTesting(bool online) => _setOnline(online);

  void _setOnline(bool online) {
    if (online) {
      _offlinePoll?.cancel();
      _offlinePoll = null;
    } else {
      _offlinePoll ??= Timer.periodic(
        _offlinePollInterval,
        (_) => unawaited(checkNow()),
      );
    }
    if (_isOnline == online) return;
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _offlinePoll?.cancel();
    super.dispose();
  }
}

/// Thrown by network-only actions (scenario backend, Hati chat) when the
/// device is offline, so callers can show [message] as-is instead of a raw
/// socket/timeout error.
class OfflineException implements Exception {
  const OfflineException([
    this.message =
        "You're offline right now. Check your internet connection and try "
        'again.',
  ]);

  final String message;

  @override
  String toString() => message;
}
