import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'post_assessment_repository.dart';

/// On-device notification reminding the user their 2-week check-in is due
/// — a separate delivery channel from the in-app
/// `ReassessmentBanner`/profile "Check-in" card, since those only reach the
/// user while the app happens to be open. Opt-in: stays off until the user
/// turns it on from the profile screen's Notifications settings, since
/// enabling it needs an OS-level permission grant on Android 13+ / iOS.
class ReassessmentNotificationService {
  ReassessmentNotificationService._();

  static const _notificationId = 1001;
  static const _channelId = 'reassessment_reminders';
  static const _channelName = 'Check-in reminders';
  static const _channelDescription =
      "Reminds you when your 2-week HATI check-in is ready";

  static const _firestoreField = 'reassessmentNotificationsEnabled';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
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

  static Future<bool> isEnabled(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?[_firestoreField] == true;
  }

  /// Turns the reminder on/off for [uid]. Turning on requests the OS
  /// notification permission first — if the user denies it, the setting is
  /// left off rather than silently saved as "on" with nothing able to
  /// display. Returns the state that actually ended up persisted, so the
  /// settings toggle can reflect what really happened.
  static Future<bool> setEnabled(String uid, bool enabled) async {
    var effective = enabled;
    if (enabled) {
      effective = await requestPermission();
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      _firestoreField: effective,
    }, SetOptions(merge: true));
    await sync(uid);
    return effective;
  }

  /// Prompts for the OS notification permission (Android 13+ / iOS 10+).
  /// Returns whether it's granted. Safe to call even if already granted —
  /// the OS just returns the current state without re-prompting.
  static Future<bool> requestPermission() async {
    await _ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  /// Re-evaluates and (re)schedules the reminder for [uid] against their
  /// current due date, cancelling any pending one first: disabled, no
  /// baseline yet, or the due date has already passed (the in-app
  /// banner/profile card handle that case — this reminder is only useful
  /// for a due date still ahead). Doesn't prompt for permission itself —
  /// call [requestPermission] (or [setEnabled]) for that — so this is safe
  /// to call opportunistically (app start, after completing a check-in)
  /// without risking a repeated OS permission prompt.
  static Future<void> sync(String uid) async {
    final enabled = await isEnabled(uid);
    if (!enabled) {
      await cancel();
      return;
    }

    final baseline = await PostAssessmentRepository.getBaseline(uid);
    final dueDate = baseline?.administeredAt.add(reassessmentCooldown);
    if (dueDate == null || !dueDate.isAfter(DateTime.now())) {
      await cancel();
      return;
    }

    await _ensureInitialized();
    final scheduled = tz.TZDateTime.from(dueDate.toUtc(), tz.UTC);
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: "It's time for your 2-week check-in",
      body:
          'A quick reassessment to see how things are going since you '
          'started with HATI.',
      scheduledDate: scheduled,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancel() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
  }
}
