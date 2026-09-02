import 'package:shared_preferences/shared_preferences.dart';

/// How long a signed-in session is trusted before the app asks the user to
/// log in again — a rolling window: opening the app at all within this
/// period (see [recordLoginTimestamp], called from every
/// [navigateAfterAuth] pass) resets the clock, so an active user is never
/// interrupted. Only someone who hasn't opened the app in over a month
/// gets sent back to the login screen, even though Firebase Auth itself
/// would otherwise keep them signed in indefinitely.
const sessionReloginInterval = Duration(days: 30);

const _lastLoginKey = 'hati_last_login_at';

/// Records "now" as the last confirmed signed-in app open.
Future<void> recordLoginTimestamp() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
}

/// Whether the last recorded sign-in is still within
/// [sessionReloginInterval]. Returns false — forcing a fresh login — if
/// nothing was ever recorded, which covers both a brand-new install and an
/// existing install from before this feature existed.
Future<bool> isLoginSessionStillValid() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_lastLoginKey);
  if (raw == null) return false;
  final lastLogin = DateTime.tryParse(raw);
  if (lastLogin == null) return false;
  return DateTime.now().difference(lastLogin) < sessionReloginInterval;
}

/// Clears the recorded timestamp. Call this alongside sign-out so a manual
/// logout doesn't leave a stale "still valid" window behind.
Future<void> clearLoginTimestamp() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_lastLoginKey);
}
