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

/// Which mood/pose an NPC's Rive sprite should play for a given line —
/// see [NpcCharacter.sprites] and `_buildSpeakerBlocks` in
/// scene3_interaction.dart for the heuristic that picks one per turn.
enum NpcMood { blink, greet, tilt, frown }

/// Per-character mood -> Rive asset mapping. All four fields are required;
/// scenarios whose art only ships a subset of poses (e.g. the "strict
/// prof" bald character, which only has blink/annoyed art, reused as-is
/// from foa_supervisor) fill the missing moods with the closest available
/// file instead of leaving them null — see fbop_spotlight's "Cruz" entry
/// in [kScenarioConfigs].
class NpcMoodSprites {
  final String blink;
  final String greet;
  final String tilt;
  final String frown;

  const NpcMoodSprites({
    required this.blink,
    required this.greet,
    required this.tilt,
    required this.frown,
  });

  String forMood(NpcMood mood) {
    switch (mood) {
      case NpcMood.blink:
        return blink;
      case NpcMood.greet:
        return greet;
      case NpcMood.tilt:
        return tilt;
      case NpcMood.frown:
        return frown;
    }
  }
}

/// One NPC character reachable within a multi-NPC scenario turn (e.g. one
/// of the 5 professors in fbop_spotlight, or the single "Stranger" in
/// fsn_seat). [matchKeywords] are lowercase substrings matched against the
/// *raw*, unnormalized speaker-prefix text captured by [parseSpeakerMessage]
/// — see [resolveNpcCharacter]. Substring (not equality) matching is
/// required because scenario_engine.py's speaker-prefix format for the same
/// character varies across Easy/Difficult mode and even within one mode
/// (e.g. "Professor 2 (Sir Cruz, stern)" vs "Professor 2 (Dr. Cruz)" vs a
/// bare "Sir Cruz") — every real variant, verified against the backend
/// source, always contains the character's surname/first-name keyword.
/// [displayName] is the clean, consistent name shown in the UI regardless
/// of which raw variant the backend actually sent that turn.
class NpcCharacter {
  final String id;
  final String displayName;
  final List<String> matchKeywords;
  final NpcMoodSprites sprites;

  const NpcCharacter({
    required this.id,
    required this.displayName,
    required this.matchKeywords,
    required this.sprites,
  });

  bool matches(String rawSpeaker) {
    final s = rawSpeaker.toLowerCase();
    return matchKeywords.any((k) => s.contains(k));
  }
}

/// Finds which of [config]'s NPC characters spoke a line whose raw speaker
/// prefix text is [rawSpeaker], by surname/keyword substring match (see
/// [NpcCharacter.matchKeywords]). Falls back to the scenario's one-and-only
/// character when [config] has exactly one — fsn_seat ("Stranger") and
/// phys_jeepney ("Classmate") are single-NPC scenarios, so any non-Hati,
/// non-Narrator line there is always that one NPC no matter the exact
/// wording of its speaker prefix.
NpcCharacter? resolveNpcCharacter(ScenarioConfig config, String rawSpeaker) {
  for (final character in config.npcCharacters) {
    if (character.matches(rawSpeaker)) return character;
  }
  if (config.npcCharacters.length == 1) return config.npcCharacters.first;
  return null;
}

/// True if [speaker] is Hati or a Hati variant (e.g. "Hati (sidebar)",
/// used a couple of times in fbop_spotlight's Easy-mode script). A
/// startsWith match rather than equality, for the same reason as
/// [NpcCharacter.matchKeywords].
bool isHatiSpeaker(String? speaker) =>
    (speaker ?? '').trim().toLowerCase().startsWith('hati');

/// True if [speaker] is the "Narrator" scene-description line used across
/// every multi-NPC scenario (e.g. "**Narrator:** Sir Cruz nods once.") —
/// rendered as plain narration rather than attributed to any character.
bool isNarratorSpeaker(String? speaker) =>
    (speaker ?? '').trim().toLowerCase().startsWith('narrator');

/// Per-scenario presentation config: background art, optional character
/// sprite, and the theme/title strings sent to the backend + shown in UI.
///
/// `foa_supervisor` keeps its bespoke classroom art (background + prof
/// sprite via [spriteAsset]/[spriteAssetAngry]). The 5 multi/single-NPC
/// scenarios (fbop_spotlight, fne_stage, fsg_party, fsn_seat, phys_jeepney)
/// instead populate [npcCharacters] — [Scene3Interaction] branches on
/// whether that list is empty to pick which rendering path to use, so
/// every other scenario (including foa_classroom, with no character art at
/// all) keeps rendering full-bleed background art only, exactly as before.
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
  // Per-character sprite/mood art for multi/single-NPC scenarios. Empty
  // for scenarios that don't use this system (foa_supervisor/foa_classroom
  // and any unmapped key), in which case Scene3Interaction falls back to
  // the single [spriteAsset]/[spriteAssetAngry] pair.
  final List<NpcCharacter> npcCharacters;

  const ScenarioConfig({
    required this.scenarioKey,
    required this.theme,
    required this.title,
    required this.backgroundAsset,
    this.spriteAsset,
    this.spriteAssetAngry,
    required this.assetPrefix,
    this.npcCharacters = const [],
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
    // Single-NPC scenario ("Stranger") — only asset the user provided is a
    // girl character, so the stranger is female here.
    npcCharacters: [
      NpcCharacter(
        id: 'fsn_stranger',
        displayName: 'Stranger',
        matchKeywords: ['stranger'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fsn/girl/fem_misc_blink.riv',
          greet: 'assets/scenario_npcs/fsn/girl/fem_misc_greet.riv',
          tilt: 'assets/scenario_npcs/fsn/girl/fem_misc__tilt.riv',
          frown: 'assets/scenario_npcs/fsn/girl/fem_misc_frown.riv',
        ),
      ),
    ],
  ),
  'fbop_spotlight': ScenarioConfig(
    scenarioKey: 'fbop_spotlight',
    theme: 'Fear of Being Observed & Performing',
    title: 'Project Defense: Defended or Offended',
    backgroundAsset: 'assets/scenario_background/fbop_background.png',
    assetPrefix: 'fbop',
    // 5-professor panel — Reyes, Santos, Garcia share the generic male
    // professor asset; Lopez is the girl professor; Cruz is the strict/bald
    // professor (same asset already used by foa_supervisor).
    npcCharacters: [
      NpcCharacter(
        id: 'fbop_reyes',
        displayName: 'Dr. Reyes',
        matchKeywords: ['reyes'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fbop/male prof/male_prof_blink.riv',
          greet: 'assets/scenario_npcs/fbop/male prof/male_prof_greet.riv',
          tilt: 'assets/scenario_npcs/fbop/male prof/male_prof_tilt.riv',
          frown: 'assets/scenario_npcs/fbop/male prof/male_prof_frown.riv',
        ),
      ),
      NpcCharacter(
        id: 'fbop_cruz',
        displayName: 'Dr. Cruz',
        matchKeywords: ['cruz'],
        sprites: NpcMoodSprites(
          // "Strict prof" bald asset only ships blink/annoyed — reuse
          // blink for greet/tilt (no dedicated art) and annoyed for frown,
          // same fallback the foa_supervisor bald character already uses.
          blink: 'assets/scenario_npcs/fbop/strict prof/bald_blink.riv',
          greet: 'assets/scenario_npcs/fbop/strict prof/bald_blink.riv',
          tilt: 'assets/scenario_npcs/fbop/strict prof/bald_blink.riv',
          frown: 'assets/scenario_npcs/fbop/strict prof/bald_annoyed.riv',
        ),
      ),
      NpcCharacter(
        id: 'fbop_santos',
        displayName: 'Dr. Santos',
        matchKeywords: ['santos'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fbop/male prof/male_prof_blink.riv',
          greet: 'assets/scenario_npcs/fbop/male prof/male_prof_greet.riv',
          tilt: 'assets/scenario_npcs/fbop/male prof/male_prof_tilt.riv',
          frown: 'assets/scenario_npcs/fbop/male prof/male_prof_frown.riv',
        ),
      ),
      NpcCharacter(
        id: 'fbop_garcia',
        displayName: 'Dr. Garcia',
        matchKeywords: ['garcia'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fbop/male prof/male_prof_blink.riv',
          greet: 'assets/scenario_npcs/fbop/male prof/male_prof_greet.riv',
          tilt: 'assets/scenario_npcs/fbop/male prof/male_prof_tilt.riv',
          frown: 'assets/scenario_npcs/fbop/male prof/male_prof_frown.riv',
        ),
      ),
      NpcCharacter(
        id: 'fbop_lopez',
        displayName: 'Dr. Lopez',
        matchKeywords: ['lopez'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fbop/girl prof/female_prof_blink_.riv',
          greet: 'assets/scenario_npcs/fbop/girl prof/female_prof_greet.riv',
          tilt: 'assets/scenario_npcs/fbop/girl prof/female_prof_tilt.riv',
          frown: 'assets/scenario_npcs/fbop/girl prof/female_prof_frown.riv',
        ),
      ),
    ],
  ),
  'fsg_party': ScenarioConfig(
    scenarioKey: 'fsg_party',
    theme: 'Fear of Social Gatherings',
    title: 'The House Party: To Approach or Not?',
    backgroundAsset: 'assets/scenario_background/fsg_background.png',
    assetPrefix: 'fsg',
    // Julia and Precious share the girl asset; Jaspher is the boy.
    npcCharacters: [
      NpcCharacter(
        id: 'fsg_julia',
        displayName: 'Julia',
        matchKeywords: ['julia'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fsg/girl/fem_misc_blink.riv',
          greet: 'assets/scenario_npcs/fsg/girl/fem_misc_greet.riv',
          tilt: 'assets/scenario_npcs/fsg/girl/fem_misc__tilt.riv',
          frown: 'assets/scenario_npcs/fsg/girl/fem_misc_frown.riv',
        ),
      ),
      NpcCharacter(
        id: 'fsg_precious',
        displayName: 'Precious',
        matchKeywords: ['precious'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fsg/girl/fem_misc_blink.riv',
          greet: 'assets/scenario_npcs/fsg/girl/fem_misc_greet.riv',
          tilt: 'assets/scenario_npcs/fsg/girl/fem_misc__tilt.riv',
          frown: 'assets/scenario_npcs/fsg/girl/fem_misc_frown.riv',
        ),
      ),
      NpcCharacter(
        id: 'fsg_jaspher',
        displayName: 'Jaspher',
        matchKeywords: ['jaspher'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fsg/boy/misc_blink.riv',
          greet: 'assets/scenario_npcs/fsg/boy/misc_greet.riv',
          tilt: 'assets/scenario_npcs/fsg/boy/misc_tilt_head.riv',
          frown: 'assets/scenario_npcs/fsg/boy/misc_frown.riv',
        ),
      ),
    ],
  ),
  'fne_stage': ScenarioConfig(
    scenarioKey: 'fne_stage',
    theme: 'Fear of Negative Evaluation & Embarrassment',
    title: 'The Group Project: Defending Your Work',
    backgroundAsset: 'assets/scenario_background/fne_background.png',
    assetPrefix: 'fne',
    // Julia and Precious share the girl student asset; Carlo is the boy
    // (there is no separate strict-professor-style asset for fne — Carlo
    // just uses the plain male student set).
    npcCharacters: [
      NpcCharacter(
        id: 'fne_carlo',
        displayName: 'Carlo',
        matchKeywords: ['carlo'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/fne/male student/male_student_blink.riv',
          greet: 'assets/scenario_npcs/fne/male student/male_student_greet.riv',
          tilt: 'assets/scenario_npcs/fne/male student/male_student_tilt.riv',
          frown: 'assets/scenario_npcs/fne/male student/male_student_frown.riv',
        ),
      ),
      NpcCharacter(
        id: 'fne_julia',
        displayName: 'Julia',
        matchKeywords: ['julia'],
        sprites: NpcMoodSprites(
          blink:
              'assets/scenario_npcs/fne/girl student/student_girl_blink_.riv',
          greet: 'assets/scenario_npcs/fne/girl student/student_girl_greet.riv',
          tilt: 'assets/scenario_npcs/fne/girl student/student_girl_tilt.riv',
          frown: 'assets/scenario_npcs/fne/girl student/student_girl_frown.riv',
        ),
      ),
      NpcCharacter(
        id: 'fne_precious',
        displayName: 'Precious',
        matchKeywords: ['precious'],
        sprites: NpcMoodSprites(
          blink:
              'assets/scenario_npcs/fne/girl student/student_girl_blink_.riv',
          greet: 'assets/scenario_npcs/fne/girl student/student_girl_greet.riv',
          tilt: 'assets/scenario_npcs/fne/girl student/student_girl_tilt.riv',
          frown: 'assets/scenario_npcs/fne/girl student/student_girl_frown.riv',
        ),
      ),
    ],
  ),
  'phys_jeepney': ScenarioConfig(
    scenarioKey: 'phys_jeepney',
    theme: 'Physiological Symptoms',
    title: 'The Bus Stop: Hiding Visible Anxiety',
    backgroundAsset: 'assets/scenario_background/phys_background.png',
    assetPrefix: 'phys',
    // Single-NPC scenario ("Classmate") — only asset provided is a girl
    // character, so the classmate is female here.
    npcCharacters: [
      NpcCharacter(
        id: 'phys_classmate',
        displayName: 'Classmate',
        matchKeywords: ['classmate'],
        sprites: NpcMoodSprites(
          blink: 'assets/scenario_npcs/phys/girl/fem_misc_blink.riv',
          greet: 'assets/scenario_npcs/phys/girl/fem_misc_greet.riv',
          tilt: 'assets/scenario_npcs/phys/girl/fem_misc__tilt.riv',
          frown: 'assets/scenario_npcs/phys/girl/fem_misc_frown.riv',
        ),
      ),
    ],
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

  // Shared Easy/Difficult mode selector — runs after every theme's
  // prep/goal-setting scene2_* steps, right before Scene 3 begins. Rendered
  // via Scene2Preparation (see scene2_preparation.dart's special-case for
  // this step name) rather than falling through to the preScene default.
  'scene2_difficulty': SceneId.preparation,

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
  'scene4_class_npc_done': SceneId.debrief,

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
  'foa_s2_goal': SceneId.preparation,
  'foa_s2_ready': SceneId.preparation,
  'foa_s3_npc': SceneId.interaction,
  'foa_s3_custom': SceneId.interaction,
  'foa_s3_reaction': SceneId.interaction,
  'foa_diff_s3_npc': SceneId.interaction,
  'foa_diff_s3_reaction': SceneId.interaction,

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
  'fsn_s2_practice_custom': SceneId.preparation,
  'fsn_s2_goal': SceneId.preparation,
  'fsn_s2_ground': SceneId.preparation,
  'fsn_s2_ready': SceneId.preparation,
  'fsn_s3_npc': SceneId.interaction,
  'fsn_s3_custom': SceneId.interaction,
  'fsn_s3_reaction': SceneId.interaction,
  'fsn_diff_s3_npc': SceneId.interaction,
  'fsn_diff_s3_reaction': SceneId.interaction,

  // ── fbop_spotlight preparation/interaction ──────────────────────────────
  'fbop_s2_title': SceneId.preparation,
  'fbop_s2_topic_about': SceneId.preparation,
  'fbop_s2_topic_point': SceneId.preparation,
  'fbop_s2_topic_why': SceneId.preparation,
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
  'fbop_diff_s3_delivery': SceneId.interaction,
  'fbop_diff_s3_reaction': SceneId.interaction,

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
  'fsg_diff_s3_approach': SceneId.interaction,
  'fsg_diff_s3_reaction': SceneId.interaction,

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
  'fne_diff_s3_delivery': SceneId.interaction,
  'fne_diff_s3_reaction': SceneId.interaction,

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
  'phys_diff_s3_classmate': SceneId.interaction,
  'phys_diff_s3_reaction': SceneId.interaction,
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
// Fallback for a malformed-but-real variant found in scenario_engine.py
// (fbop_spotlight Easy mode): "**Professor 1 (Sir Reyes, neutral but
// noticing)**: Take your time..." — the closing "**" lands BEFORE the
// colon instead of after it. Tried only when the primary pattern above
// doesn't match, so well-formed "**Speaker:**" text is unaffected.
final RegExp _kSpeakerPrefixAlt = RegExp(r'^\*\*([^*:]+)\*\*:\s*');

String _stripBoldMarkers(String s) => s.replaceAll('**', '');

ParsedMessage parseSpeakerMessage(String raw) {
  final match =
      _kSpeakerPrefix.firstMatch(raw) ?? _kSpeakerPrefixAlt.firstMatch(raw);
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
