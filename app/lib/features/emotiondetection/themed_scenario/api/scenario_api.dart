// ─────────────────────────────────────────────
// HATI – Themed Scenario: thin HTTP client
// api/scenario_api.dart
//
// Mirrors scenario_game.dart's request handling (same base URL, same
// endpoint shapes) but is intentionally standalone: this feature never
// imports from scenario_game.dart. Generic across every scenario key/theme
// pair — `theme`/`scenario_key` are supplied by the caller per-request
// (see ScenarioProvider.start) rather than hardcoded here.
// ─────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP client shared by every themed scenario. Talks to
/// `/scenario/start|step|step_audio` with whatever `theme`/`scenario_key`
/// it's given.
class ScenarioApi {
  static const String baseUrl =
      "https://hati-backend.gentlewave-19ed4c84.southeastasia.azurecontainerapps.io";

  /// Without a timeout, an unreachable [baseUrl] (server not running, IP
  /// changed, device on a different network) just hangs indefinitely with
  /// no error — the scenario looks "stuck loading" forever instead of
  /// failing visibly. This caps every request so ScenarioProvider's
  /// try/catch always gets a chance to surface a real error message.
  ///
  /// 60s, not 15s: the backend runs on Azure Container Apps' consumption
  /// plan, which scales to zero when idle — a "cold start" has to boot
  /// Python, load VGGish, 4 from-scratch ensemble members, the fine-tuned
  /// text model, and Whisper before it can answer its first request. QA
  /// testing (ver 1.0) hit exactly this: a real, reachable backend that
  /// just hadn't finished starting up yet inside the old 15s window,
  /// which _throwUnreachable()'s wording below misleadingly blamed on the
  /// user's network instead.
  static const Duration _requestTimeout = Duration(seconds: 60);

  Never _throwUnreachable() {
    throw Exception(
      "Couldn't reach the scenario server. It may still be starting up "
      "(this can take up to a minute after being idle) — please try "
      "again in a moment. If it still doesn't connect, check that this "
      "device has a working internet connection.",
    );
  }

  /// A 429 means the backend's own rate limiter kicked in (see app.py's
  /// _rate_limit) — extremely unlikely from normal gameplay pace, but
  /// without this special case it fell through to the generic "Server
  /// error: 429" message below, which reads like a bug rather than "you're
  /// going a bit fast."
  Never _throwServerError(int statusCode, [String body = '']) {
    if (statusCode == 429) {
      throw Exception(
        "You're sending responses a little too fast — please wait a "
        "moment and try again.",
      );
    }
    throw Exception(
      body.isEmpty ? "Server error: $statusCode" : "Server error: $statusCode $body",
    );
  }

  /// The backend now verifies a real Firebase ID token on every
  /// /scenario/* call instead of trusting the plain `user_id` field in the
  /// request body (that let any caller substitute someone else's uid and
  /// read/overwrite their scenario data). `getIdToken()` is cheap to call
  /// on every request — the Firebase SDK caches the token locally and only
  /// hits the network to refresh it once it's actually close to expiring.
  Future<String> _authHeader() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception("You're signed out — please log in again to continue.");
    }
    return "Bearer $token";
  }

  Future<Map<String, dynamic>> start({
    required String scenarioKey,
    required String theme,
    required String userId,
    String? userName,
    bool forceNew = false,
  }) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse("$baseUrl/scenario/start"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": await _authHeader(),
            },
            body: jsonEncode({
              "theme": theme,
              "scenario_key": scenarioKey,
              if (userName != null && userName.trim().isNotEmpty)
                "user_name": userName.trim(),
              "user_id": userId,
              "force_new": forceNew,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      _throwUnreachable();
    } on SocketException {
      _throwUnreachable();
    }

    if (response.statusCode != 200) {
      _throwServerError(response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> step({
    required String sessionId,
    required String text,
    String? userName,
    required String userId,
  }) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse("$baseUrl/scenario/step"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": await _authHeader(),
            },
            body: jsonEncode({
              "session_id": sessionId,
              "text": text,
              if (userName != null && userName.trim().isNotEmpty)
                "user_name": userName.trim(),
              "user_id": userId,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      _throwUnreachable();
    } on SocketException {
      _throwUnreachable();
    }

    if (response.statusCode != 200) {
      _throwServerError(response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> stepAudio({
    required String sessionId,
    required String userId,
    required String filePath,
  }) async {
    final uri = Uri.parse("$baseUrl/scenario/step_audio");
    final request = http.MultipartRequest("POST", uri);
    request.headers["Authorization"] = await _authHeader();
    request.fields["session_id"] = sessionId;
    request.fields["user_id"] = userId;
    request.files.add(
      await http.MultipartFile.fromPath(
        "audio",
        filePath,
        filename: "record.wav",
      ),
    );

    final http.Response response;
    try {
      final streamed = await request.send().timeout(_requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      _throwUnreachable();
    } on SocketException {
      _throwUnreachable();
    }

    if (response.statusCode != 200) {
      _throwServerError(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
