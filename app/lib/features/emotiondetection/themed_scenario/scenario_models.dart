// ─────────────────────────────────────────────
// HATI – Themed Scenario: models
// scenario_models.dart
//
// Backend-driven models: SceneId is derived purely from the backend's raw
// FSM `step` string (see kStepToScene below, verified against
// scenario_engine.py across all 7 reachable scenarios). Nothing here is
// scenario branching logic — that stays authoritative server-side.
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

/// Per-scenario presentation config: background art, optional character
/// sprite, and the theme/title strings sent to the backend + shown in UI.
///
/// `foa_supervisor` keeps its bespoke classroom art (background + prof
/// sprite). The other 6 scenarios have no bespoke character sprite, so
/// [spriteAsset] is null for them — [Scene3Interaction] renders full-bleed
/// background art only, with the sprite portion of the widget skipped.
class ScenarioConfig {
  final String scenarioKey;
  final String theme;
  final String title;
  final String backgroundAsset;
  final String? spriteAsset;
  // Alternate NPC sprite/animation shown while ScenarioProvider.npcMood is
  // "angry" (see scenario_provider.dart, driven by the backend's per-turn
  // npc_mood field). Null for scenarios with no mood-specific art — they
  // just keep showing [spriteAsset].
  final String? spriteAssetAngry;
  // Short filename prefix used across scenario_background/, scenario_npcs/,
  // and scenario_placeholder/ — equal to scenarioKey for every theme with
  // only one scenario, except `foa`, which has two (foa_supervisor,
  // foa_classroom) and so keeps the full key to tell them apart.
  final String assetPrefix;

  const ScenarioConfig({
    required this.scenarioKey,
    required this.theme,
    required this.title,
    required this.backgroundAsset,
    this.spriteAsset,
    this.spriteAssetAngry,
    required this.assetPrefix,
  });

  /// `assets/scenario_placeholder/{assetPrefix}_placeholder.png` — always
  /// derivable (every scenario has one, unlike [spriteAsset]), so it's
  /// computed rather than repeated per entry in [kScenarioConfigs]. PNG
  /// (not SVG): this art is always a flattened raster export, and
  /// flutter_svg doesn't reliably support the layered/masked SVG features
  /// some design tools export, causing partial/silhouette rendering.
  String get placeholderAsset =>
      'assets/scenario_placeholder/${assetPrefix}_placeholder.png';
}

/// Default background used for any scenario key not present in
/// [kScenarioConfigs] (shouldn't happen for the 7 known reachable
/// scenarios, but keeps [scenarioConfigFor] total/safe).
const String _kFallbackBackground =
    'assets/scenario_background/foa_supervisor_background.png';

/// Per-scenario art lives in three flat folders — `scenario_background/`,
/// `scenario_placeholder/`, `scenario_npcs/` — one file per scenario, named
/// `{assetPrefix}_background.{ext}` etc. Drop a same-named file in to swap
/// the art — no code changes needed, just a hot-restart/rebuild so Flutter
/// re-reads the bundled asset. [ScenarioConfig.assetPrefix] is the same as
/// scenarioKey except for `foa`, which has two scenarios and so keeps its
/// full key in filenames to avoid a collision.
///
/// One row per reachable scenario, verified against modules_screen.dart's
/// scenario grid and scenario_engine.py's THEME_SCENARIO_KEYS.
const Map<String, ScenarioConfig> kScenarioConfigs = {
  'foa_supervisor': ScenarioConfig(
    scenarioKey: 'foa_supervisor',
    theme: 'Fear of Authority',
    title: "The Professor's Signature",
    backgroundAsset: 'assets/scenario_background/foa_supervisor_background.png',
    spriteAsset: 'assets/scenario_npcs/foa_supervisor/bald_blink.riv',
    spriteAssetAngry: 'assets/scenario_npcs/foa_supervisor/bald_annoyed.riv',
    assetPrefix: 'foa_supervisor',
  ),
  'foa_classroom': ScenarioConfig(
    scenarioKey: 'foa_classroom',
    theme: 'Fear of Authority',
    title: 'WHERE TO SIT?',
    backgroundAsset: 'assets/scenario_background/foa_classroom_background.png',
    assetPrefix: 'foa_classroom',
  ),
  'fsn_seat': ScenarioConfig(
    scenarioKey: 'fsn_seat',
    theme: 'Fear of Strangers & New People',
    title: "The Food Hall's Seat",
    backgroundAsset: 'assets/scenario_background/fsn_background.png',
    assetPrefix: 'fsn',
  ),
  'fbop_spotlight': ScenarioConfig(
    scenarioKey: 'fbop_spotlight',
    theme: 'Fear of Being Observed & Performing',
    title: 'Project Defense: Defended or Offended',
    backgroundAsset: 'assets/scenario_background/fbop_background.png',
    assetPrefix: 'fbop',
  ),
  'fsg_party': ScenarioConfig(
    scenarioKey: 'fsg_party',
    theme: 'Fear of Social Gatherings',
    title: 'The House Party: To Approach or Not?',
    backgroundAsset: 'assets/scenario_background/fsg_background.png',
    assetPrefix: 'fsg',
  ),
  'fne_stage': ScenarioConfig(
    scenarioKey: 'fne_stage',
    theme: 'Fear of Negative Evaluation & Embarrassment',
    title: 'The Group Project: Defending Your Work',
    backgroundAsset: 'assets/scenario_background/fne_background.png',
    assetPrefix: 'fne',
  ),
  'phys_jeepney': ScenarioConfig(
    scenarioKey: 'phys_jeepney',
    theme: 'Physiological Symptoms',
    title: 'The Bus Stop: Hiding Visible Anxiety',
    backgroundAsset: 'assets/scenario_background/phys_background.png',
    assetPrefix: 'phys',
  ),
};

/// Look up the config for [scenarioKey], falling back to a config built
/// from the caller-supplied [theme]/[title] with a generic background if
/// the key isn't one of the known 7 (defensive only — every call site
/// today passes one of the mapped keys).
ScenarioConfig scenarioConfigFor(
  String scenarioKey, {
  required String theme,
  required String title,
}) {
  final known = kScenarioConfigs[scenarioKey];
  if (known != null) return known;
  return ScenarioConfig(
    scenarioKey: scenarioKey,
    theme: theme,
    title: title,
    backgroundAsset: _kFallbackBackground,
    assetPrefix: scenarioKey,
  );
}

/// Step-name -> SceneId lookup table, verified against
/// `scenario_engine.py`'s `handle_step` across all 7 reachable scenarios
/// (foa_supervisor, foa_classroom, fsn_seat, fbop_spotlight, fsg_party,
/// fne_stage, phys_jeepney).
const Map<String, SceneId> kStepToScene = {
  // ── Shared across every scenario ──────────────────────────────────────
  'scene0_greet': SceneId.preScene,

  'pies_physical': SceneId.office,
  'pies_emotional': SceneId.office,
  'pies_environmental': SceneId.office,

  'scene4_debrief_intro': SceneId.debrief,
  'scene4_predicted': SceneId.debrief,
  'scene4_actual': SceneId.debrief,
  'scene4_bad': SceneId.debrief,
  'scene4_bad_detail': SceneId.debrief,
  'scene4_credit': SceneId.debrief,
  'scene4_personalized': SceneId.debrief,
  // Reflection detour some themes take.
  'scene4_reflection': SceneId.debrief,
  'scene4_class_npc_reflect': SceneId.debrief,

  'scene5_coping': SceneId.coping,
  'scene5_coping_done': SceneId.coping,

  'scene6_closing': SceneId.closing,

  'scene7_dashboard': SceneId.dashboard,
  // Terminal/unreachable in normal flow; fall back to the dashboard scene
  // rather than crashing if the backend ever returns it.
  'complete': SceneId.dashboard,

  // ── fsg_party-only debrief sub-steps ───────────────────────────────────
  'scene4_fsg_cause': SceneId.debrief,
  'scene4_fsg_badness': SceneId.debrief,
  'scene4_fsg_goal_done': SceneId.debrief,

  // ── fne_stage-only debrief sub-steps ───────────────────────────────────
  'scene4_fne_observe': SceneId.debrief,
  'scene4_fne_severity': SceneId.debrief,
  'scene4_fne_goal_done': SceneId.debrief,

  // ── foa_supervisor preparation/interaction ─────────────────────────────
  'foa_s2_script': SceneId.preparation,
  'foa_s2_script_custom': SceneId.preparation,
  'foa_s2_q_prep': SceneId.preparation,
  'foa_s2_ready': SceneId.preparation,
  'foa_s3_npc': SceneId.interaction,
  'foa_s3_custom': SceneId.interaction,
  'foa_s3_reaction': SceneId.interaction,

  // ── foa_classroom ("WHERE TO SIT?") preparation/interaction ────────────
  // Generic step names shared server-side with the (unreachable from this
  // UI) fsn_classroom scenario; foa_classroom is the only reachable
  // scenario in this UI that uses them.
  'scene2_goal': SceneId.preparation,
  'scene2_line_choice': SceneId.preparation,
  'scene2_line_custom': SceneId.preparation,
  'scene2_ready': SceneId.preparation,
  'scene3_npc_prompt': SceneId.interaction,
  'scene3_user_response': SceneId.interaction,
  'scene3_npc_reaction': SceneId.interaction,

  // ── fsn_seat preparation/interaction ────────────────────────────────────
  'fsn_s2_practice': SceneId.preparation,
  'fsn_s2_goal': SceneId.preparation,
  'fsn_s2_ready': SceneId.preparation,
  'fsn_s3_npc': SceneId.interaction,
  'fsn_s3_custom': SceneId.interaction,
  'fsn_s3_reaction': SceneId.interaction,

  // ── fbop_spotlight preparation/interaction ──────────────────────────────
  'fbop_s2_title': SceneId.preparation,
  'fbop_s2_opening': SceneId.preparation,
  'fbop_s2_opening_custom': SceneId.preparation,
  'fbop_s2_pause': SceneId.preparation,
  'fbop_s2_contrib': SceneId.preparation,
  'fbop_s2_goal': SceneId.preparation,
  'fbop_s2_goal_custom': SceneId.preparation,
  'fbop_s2_ground': SceneId.preparation,
  'fbop_s2_ready': SceneId.preparation,
  'fbop_s3_delivery': SceneId.interaction,
  'fbop_s3_outcome': SceneId.interaction,

  // ── fsg_party preparation/interaction ───────────────────────────────────
  'fsg_s2_path': SceneId.preparation,
  'fsg_a_opening': SceneId.preparation,
  'fsg_a_opening_custom': SceneId.preparation,
  'fsg_a_practice_pause': SceneId.preparation,
  'fsg_a_relation': SceneId.preparation,
  'fsg_a_goal': SceneId.preparation,
  'fsg_a_goal_custom': SceneId.preparation,
  'fsg_b_goal': SceneId.preparation,
  'fsg_b_goal_custom': SceneId.preparation,
  'fsg_ground': SceneId.preparation,
  'fsg_s2_proceed': SceneId.preparation,
  'fsg_s3_social': SceneId.interaction,
  'fsg_s3_reaction': SceneId.interaction,

  // ── fne_stage preparation/interaction ───────────────────────────────────
  'fne_s2_style': SceneId.preparation,
  'fne_s2_style_custom': SceneId.preparation,
  'fne_s2_pause': SceneId.preparation,
  'fne_s2_points': SceneId.preparation,
  'fne_s2_goal': SceneId.preparation,
  'fne_s2_goal_custom': SceneId.preparation,
  'fne_s2_ground': SceneId.preparation,
  'fne_s2_ready': SceneId.preparation,
  'fne_s3_delivery': SceneId.interaction,
  'fne_s3_carlo': SceneId.interaction,
  'fne_s3_outcome': SceneId.interaction,

  // ── phys_jeepney preparation/interaction ──────────────────────────────
  'phys_s2_excuse': SceneId.preparation,
  'phys_s2_excuse_custom': SceneId.preparation,
  'phys_s2_ack': SceneId.preparation,
  'phys_s2_goal': SceneId.preparation,
  'phys_s2_goal_custom': SceneId.preparation,
  'phys_s2_ground': SceneId.preparation,
  'phys_s2_ready': SceneId.preparation,
  'phys_s3_classmate': SceneId.interaction,
  'phys_s3_custom': SceneId.interaction,
  'phys_s3_reaction': SceneId.interaction,
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
