import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'connectivity_service.dart';

/// Thin strip pinned above every screen (installed via `MaterialApp.builder`)
/// that says when the app is offline, and briefly confirms when it's back so
/// the user knows their offline saves are syncing.
///
/// While the strip is visible it takes over the status-bar inset, so the
/// screen below gets its top padding removed instead of doubling it.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

enum _BannerMode { hidden, offline, backOnline }

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  static const _backOnlineDuration = Duration(seconds: 3);

  final _connectivity = ConnectivityService.instance;
  _BannerMode _mode = _BannerMode.hidden;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _connectivity.addListener(_onConnectivityChanged);
    if (!_connectivity.isOnline) _mode = _BannerMode.offline;
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    _hideTimer?.cancel();
    if (!_connectivity.isOnline) {
      setState(() => _mode = _BannerMode.offline);
      return;
    }
    if (_mode != _BannerMode.offline) return;
    setState(() => _mode = _BannerMode.backOnline);
    _hideTimer = Timer(_backOnlineDuration, () {
      if (mounted) setState(() => _mode = _BannerMode.hidden);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _mode != _BannerMode.hidden;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: visible ? _Strip(mode: _mode) : const SizedBox(width: double.infinity),
        ),
        // Same widget structure whether or not the strip shows — swapping
        // wrappers here would rebuild the Navigator and lose every route.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: visible,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.mode});

  final _BannerMode mode;

  @override
  Widget build(BuildContext context) {
    final offline = mode == _BannerMode.offline;
    return Material(
      color: offline ? const Color(0xFF37474F) : const Color(0xFF2E7D32),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                color: AppColors.cream,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  offline
                      ? "You're offline. Your changes are saved and will sync later."
                      : 'Back online. Syncing your changes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
