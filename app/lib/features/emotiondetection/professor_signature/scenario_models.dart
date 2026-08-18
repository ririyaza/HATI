// ─────────────────────────────────────────────
// HATI – Professor Signature: models
// scenario_models.dart
//
// Backend-driven models: SceneId is derived purely from the backend's raw
// FSM `step` string (see kStepToScene below, verified against
// scenario_engine.py). Nothing here is scenario branching logic — that
// stays authoritative server-side.
// ─────────────────────────────────────────────

/// Which themed scene widget should be on screen. Purely a presentation
/// grouping of backend step names — see [sceneForStep].
enum SceneId {
  preScene,
  office,
  preparation,
  interaction,
  debrief,
  coping,
  closing,
  dashboard,
}

enum ScenarioUIType { buttons, textInput }

/// Mirrors the `ui` object on `/scenario/start` and `/scenario/step`
/// responses: `{type: "buttons" | "text_input", options: [...]}`.
class ScenarioUI {
  final ScenarioUIType type;
  final List<String> options;
  final String? placeholder;

  const ScenarioUI({
    required this.type,
    this.options = const [],
    this.placeholder,
  });

  static const ScenarioUI empty = ScenarioUI(type: ScenarioUIType.textInput);

  factory ScenarioUI.fromJson(dynamic json) {
    if (json is! Map) {
      return ScenarioUI.empty;
    }
    final typeStr = (json["type"] ?? "text_input").toString();
    if (typeStr == "buttons") {
      final rawOptions = json["options"];
      return ScenarioUI(
        type: ScenarioUIType.buttons,
        options: rawOptions is List
            ? rawOptions.map((o) => o.toString()).toList()
            : const [],
      );
    }
    return ScenarioUI(
      type: ScenarioUIType.textInput,
      placeholder: json["placeholder"]?.toString(),
    );
  }
}

/// Step-name -> SceneId lookup table, verified against
/// `scenario_engine.py`'s `handle_step` for the `foa_supervisor` flow.
const Map<String, SceneId> kStepToScene = {
  'scene0_greet': SceneId.preScene,
  'pies_physical': SceneId.office,
  'pies_emotional': SceneId.office,
  'pies_environmental': SceneId.office,
  'foa_s2_script': SceneId.preparation,
  'foa_s2_script_custom': SceneId.preparation,
  'foa_s2_q_prep': SceneId.preparation,
  'foa_s2_ready': SceneId.preparation,
  'foa_s3_npc': SceneId.interaction,
  'foa_s3_reaction': SceneId.interaction,
  'scene4_debrief_intro': SceneId.debrief,
  'scene4_predicted': SceneId.debrief,
  'scene4_actual': SceneId.debrief,
  'scene4_bad': SceneId.debrief,
  'scene4_bad_detail': SceneId.debrief,
  'scene4_credit': SceneId.debrief,
  'scene4_personalized': SceneId.debrief,
  'scene5_coping': SceneId.coping,
  'scene5_coping_done': SceneId.coping,
  'scene6_closing': SceneId.closing,
  'scene7_dashboard': SceneId.dashboard,
  // Terminal/unreachable in normal flow; fall back to the dashboard scene
  // rather than crashing if the backend ever returns it.
  'complete': SceneId.dashboard,
};

/// Pure function: which themed scene should render for a given raw backend
/// step. Defaults to [SceneId.preScene] before the first response arrives
/// (backendStep == null) and for any unrecognized step name.
SceneId sceneForStep(String? step) {
  if (step == null) return SceneId.preScene;
  return kStepToScene[step] ?? SceneId.preScene;
}

/// A backend message with its speaker prefix (e.g. "**Hati:**",
/// "**Professor:**", "**Narrator:**") stripped and separated out, and any
/// remaining `**bold**` markdown markers removed for plain display.
class ParsedMessage {
  final String? speaker;
  final String text;

  const ParsedMessage({this.speaker, required this.text});
}

final RegExp _kSpeakerPrefix = RegExp(r'^\*\*([^*:]+):\*\*\s*');

String _stripBoldMarkers(String s) => s.replaceAll('**', '');

ParsedMessage parseSpeakerMessage(String raw) {
  final match = _kSpeakerPrefix.firstMatch(raw);
  if (match == null) {
    return ParsedMessage(text: _stripBoldMarkers(raw).trim());
  }
  final speaker = match.group(1)?.trim();
  final rest = raw.substring(match.end);
  return ParsedMessage(speaker: speaker, text: _stripBoldMarkers(rest).trim());
}

/// Convenience: parse a whole message list and join the plain text with
/// blank lines, ignoring speaker prefixes. Handy for scenes that just want
/// "everything Hati/the scene said this turn" as one block of text.
String joinMessageText(List<String> messages, {String separator = '\n\n'}) {
  return messages
      .map(parseSpeakerMessage)
      .map((m) => m.text)
      .where((t) => t.trim().isNotEmpty)
      .join(separator);
}
