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
import 'package:http/http.dart' as http;

/// Thin HTTP client shared by every themed scenario. Talks to
/// `/scenario/start|step|step_audio` with whatever `theme`/`scenario_key`
/// it's given.
class ScenarioApi {
  static const String baseUrl = "http://192.168.1.4:5000";

  /// Without a timeout, an unreachable [baseUrl] (server not running, IP
  /// changed, device on a different network) just hangs indefinitely with
  /// no error — the scenario looks "stuck loading" forever instead of
  /// failing visibly. This caps every request so ScenarioProvider's
  /// try/catch always gets a chance to surface a real error message.
  static const Duration _requestTimeout = Duration(seconds: 15);

  Never _throwUnreachable() {
    throw Exception(
      "Couldn't reach the scenario server at $baseUrl. Make sure it's "
      "running and that this device is on the same network.",
    );
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
            headers: {"Content-Type": "application/json"},
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
      throw Exception("Server error: ${response.statusCode}");
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
            headers: {"Content-Type": "application/json"},
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
      throw Exception("Server error: ${response.statusCode}");
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
      throw Exception("Server error: ${response.statusCode} ${response.body}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
