// ─────────────────────────────────────────────
// HATI – Professor Signature: Scenario Provider
// scenario_provider.dart
//
// REWRITTEN from testing_env's local state machine into a real async HTTP
// client. All branching/emotion-detection is authoritative server-side
// (scenario_engine.py) — this provider only stores the latest response and
// forwards user input verbatim via `/scenario/step` and
// `/scenario/step_audio`.
// ─────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import 'api/professor_signature_api.dart';
import 'scenario_models.dart';

class ScenarioProvider extends ChangeNotifier {
  ScenarioProvider({ProfessorSignatureApi? api})
      : _api = api ?? ProfessorSignatureApi();

  final ProfessorSignatureApi _api;

  String? sessionId;
  bool isLoading = false;
  String? errorMessage;

  /// Raw FSM step name from the backend (e.g. "pies_environmental").
  String? backendStep;
  List<String> messages = const [];
  ScenarioUI ui = ScenarioUI.empty;
  dynamic history;

  /// Set when `/scenario/start` returns `resumed: true` and the caller did
  /// not force a new session. The shell should show a "Resume scenario?"
  /// dialog and then call [confirmResume] or [discardResume].
  bool pendingResume = false;
  Map<String, dynamic>? _pendingResumeData;

  /// Last audio-turn extras, exposed for optional display.
  String? lastTranscript;
  String? lastFinalEmotion;

  String? _userId;
  String? _userName;

  SceneId get currentScene => sceneForStep(backendStep);

  Future<void> start({
    required String userId,
    String? userName,
    bool forceNew = false,
  }) async {
    _userId = userId;
    _userName = userName;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.start(
        userId: userId,
        userName: userName,
        forceNew: forceNew,
      );

      if (data["resumed"] == true && !forceNew) {
        _pendingResumeData = data;
        pendingResume = true;
        isLoading = false;
        notifyListeners();
        return;
      }

      _applyResponse(data);
    } catch (e) {
      errorMessage = "Error starting scenario: $e";
      isLoading = false;
      notifyListeners();
    }
  }

  /// User chose "Continue" on the resume dialog: apply the resumed payload
  /// that was already fetched by [start].
  Future<void> confirmResume() async {
    final data = _pendingResumeData;
    pendingResume = false;
    _pendingResumeData = null;
    if (data != null) {
      _applyResponse(data);
    } else {
      notifyListeners();
    }
  }

  /// User chose "Start over" on the resume dialog: discard the resumed
  /// payload and re-request a fresh session.
  Future<void> discardResume() async {
    pendingResume = false;
    _pendingResumeData = null;
    notifyListeners();
    await start(userId: _userId ?? '', userName: _userName, forceNew: true);
  }

  /// Used for every button tap (send the tapped option string verbatim)
  /// and every free-text field. `scenario_engine.py` never reads
  /// `selections`/`suds` for this flow — only `text` matters.
  Future<void> submitText(String text) async {
    if (sessionId == null) {
      await start(userId: _userId ?? '', userName: _userName, forceNew: true);
      if (sessionId == null) return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.step(
        sessionId: sessionId!,
        text: text,
        userName: _userName,
        userId: _userId ?? '',
      );
      _applyResponse(data);
    } catch (e) {
      errorMessage = "Error: $e";
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitAudio(String filePath, {required String userId}) async {
    if (sessionId == null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.stepAudio(
        sessionId: sessionId!,
        userId: userId,
        filePath: filePath,
      );
      lastTranscript = data["transcript"]?.toString();
      lastFinalEmotion = data["final_emotion"]?.toString();
      _applyResponse(data);
    } catch (e) {
      errorMessage = "Voice error: $e";
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (errorMessage != null) {
      errorMessage = null;
      notifyListeners();
    }
  }

  void _applyResponse(Map<String, dynamic> data) {
    final newSessionId = data["session_id"];
    if (newSessionId != null) {
      sessionId = newSessionId.toString();
    }
    backendStep = data["step"]?.toString();

    final msgs = data["messages"];
    if (msgs is List && msgs.isNotEmpty) {
      messages = msgs.map((m) => m.toString()).toList();
    } else {
      final single = data["message"];
      messages = (single != null && single.toString().isNotEmpty)
          ? [single.toString()]
          : const [];
    }

    ui = ScenarioUI.fromJson(data["ui"]);
    history = data["history"];
    isLoading = false;
    notifyListeners();
  }
}
