import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_core.dart';

/// On-device daily nudge to open HATI, separate from the 2-week check-in
/// reminder (`ReassessmentNotificationService`). Repeats every day at
/// [_hour]:[_minute] local time once scheduled. Enabled by default the
/// first time a user reaches the dashboard (see `FirstLoginNotifications`)
/// if they grant the OS permission; toggleable off afterwards from the
/// profile screen's Notifications settings.
class DailyLoginReminderService {
  DailyLoginReminderService._();

  static const _notificationId = 1002;
  static const _channelId = 'daily_login_reminders';
  static const _channelName = 'Daily reminders';
  static const _channelDescription = 'A daily nudge to open HATI';

  static const _firestoreField = 'dailyLoginNotificationsEnabled';

  // Local time the daily reminder fires at.
  static const _hour = 19;
  static const _minute = 0;

  static Future<bool> isEnabled(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?[_firestoreField] == true;
  }

  /// Turns the reminder on/off for [uid]. Turning on requests the OS
  /// notification permission first — if denied, the setting is left off
  /// rather than silently saved as "on" with nothing able to display.
  /// Returns the state that actually ended up persisted.
  static Future<bool> setEnabled(String uid, bool enabled) async {
    var effective = enabled;
    if (enabled) {
      effective = await NotificationCore.requestPermission();
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      _firestoreField: effective,
    }, SetOptions(merge: true));
    await sync(uid);
    return effective;
  }

  /// Re-evaluates and (re)schedules the daily reminder for [uid] against
  /// its current enabled state, cancelling any pending one first. Doesn't
  /// prompt for permission itself — call [setEnabled] for that — so it's
  /// safe to call opportunistically (e.g. on every dashboard load).
  static Future<void> sync(String uid) async {
    final enabled = await isEnabled(uid);
    if (!enabled) {
      await cancel();
      return;
    }

    await NotificationCore.ensureInitialized();
    await NotificationCore.plugin.zonedSchedule(
      id: _notificationId,
      title: 'Time to check in with Hati',
      body: "You haven't stopped by today — take a few minutes for HATI.",
      scheduledDate: _nextOccurrence(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static tz.TZDateTime _nextOccurrence() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _hour,
      _minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> cancel() async {
    await NotificationCore.ensureInitialized();
    await NotificationCore.plugin.cancel(id: _notificationId);
  }
}
