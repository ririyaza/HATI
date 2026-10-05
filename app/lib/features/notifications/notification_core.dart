import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Shared [FlutterLocalNotificationsPlugin] lifecycle — one-time init and
/// the OS notification permission prompt — used by every on-device
/// reminder in the app (the reassessment check-in reminder and the daily
/// login reminder), so the plugin is only initialized once and the
/// permission-request logic lives in a single place.
class NotificationCore {
  NotificationCore._();

  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // `timezone`'s `tz.local` defaults to UTC until explicitly set — without
    // this, every wall-clock schedule (e.g. the daily reminder's fixed
    // hour) fires at that hour in UTC instead of the device's actual local
    // time. Falls back to leaving it as UTC if the platform lookup fails,
    // rather than throwing and blocking notifications entirely.
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {}
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Prompts for the OS notification permission (Android 13+ / iOS 10+).
  /// Returns whether it's granted. Safe to call even if already granted or
  /// already denied — the OS just returns the current state without
  /// re-prompting.
  static Future<bool> requestPermission() async {
    await ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }
}
