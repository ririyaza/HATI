import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'connectivity_service.dart';
import 'offline_save.dart';

/// One consistent way to tell the user what happened after they tap
/// Save / Send / Continue — including the offline case, which used to be
/// either an endless spinner or a silent no-op.
///
/// Uses the root [ScaffoldMessenger], so it's safe to call right before
/// popping a sheet or replacing the route: the snackbar carries over to
/// whatever screen comes next.
abstract final class ActionFeedback {
  static const _success = Color(0xFF2E7D32);
  static const _offline = Color(0xFF37474F);
  static const _error = Color(0xFFC62828);

  /// Reports a [SaveOutcome] from [OfflineSave.run]. [savedMessage] is shown
  /// for a synced save; pass null to stay quiet in that case (e.g. when the
  /// next screen already makes success obvious).
  static void saved(
    BuildContext context,
    SaveOutcome outcome, {
    String? savedMessage = 'Saved',
    String offlineMessage =
        "Saved on this device. It'll sync automatically when you're back "
        'online.',
  }) {
    switch (outcome) {
      case SaveOutcome.synced:
        if (savedMessage != null) {
          _show(context, savedMessage, Icons.check_circle_rounded, _success);
        }
      case SaveOutcome.savedOffline:
        _show(
          context,
          offlineMessage,
          Icons.cloud_off_rounded,
          _offline,
          duration: const Duration(seconds: 4),
        );
    }
  }

  /// Shows a failure, with a Retry button when [onRetry] is given.
  static void error(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    _show(
      context,
      message,
      Icons.error_outline_rounded,
      _error,
      duration: Duration(seconds: onRetry == null ? 4 : 6),
      action: onRetry == null
          ? null
          : SnackBarAction(
              label: 'Retry',
              textColor: AppColors.cream,
              onPressed: onRetry,
            ),
    );
  }

  /// Turns an exception from a save or network call into something a user
  /// can act on, instead of a raw `[cloud_firestore/unavailable] ...`.
  static String messageFor(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is OfflineException) return error.message;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
          return const OfflineException().message;
        case 'permission-denied':
        case 'unauthenticated':
          return "You don't have permission to do that. Try signing out and "
              'back in.';
      }
    }
    if (!ConnectivityService.instance.isOnline) {
      return const OfflineException().message;
    }
    return fallback;
  }

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color background, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: background,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: action,
          content: Row(
            children: [
              Icon(icon, color: AppColors.cream, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
