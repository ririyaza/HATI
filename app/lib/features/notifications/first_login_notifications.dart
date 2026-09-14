import 'package:cloud_firestore/cloud_firestore.dart';

import '../postAssessment/data/reassessment_notification_service.dart';
import 'daily_login_reminder_service.dart';
import 'notification_core.dart';

/// Called once per account, the first time a user reaches the dashboard.
/// Asks the OS notification permission up front, and if it's granted, turns
/// on every on-device reminder in the app — the daily login nudge
/// ([DailyLoginReminderService]) and the 2-week check-in reminder
/// ([ReassessmentNotificationService]) — rather than leaving the user to
/// find and flip each toggle separately in Settings. Both stay individually
/// switchable off afterwards from the profile screen's Notifications
/// settings. Tracked via [_firstRequestField] on the user's Firestore doc
/// so this never asks again after the first time, whatever the user chose.
class FirstLoginNotifications {
  FirstLoginNotifications._();

  static const _firstRequestField = 'notificationPermissionRequested';

  static Future<void> requestOnce(String uid) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await ref.get();
    if (doc.data()?[_firstRequestField] == true) return;

    final granted = await NotificationCore.requestPermission();
    await ref.set({_firstRequestField: true}, SetOptions(merge: true));
    if (!granted) return;

    await DailyLoginReminderService.setEnabled(uid, true);
    await ReassessmentNotificationService.setEnabled(uid, true);
  }
}
