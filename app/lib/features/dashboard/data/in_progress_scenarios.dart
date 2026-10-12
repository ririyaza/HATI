import 'package:cloud_firestore/cloud_firestore.dart';

import '../../emotiondetection/themed_scenario/scenario_models.dart';

/// Progress through an unfinished session for one scenario_key. Shared by
/// the Modules tab's "% complete" pill and the dashboard data's "Modules
/// Started" count, so both always agree on what counts as in progress.
class InProgressScenario {
  final double progress;
  final bool isDifficult;
  final DateTime? updatedAt;

  const InProgressScenario({
    required this.progress,
    required this.isDifficult,
    this.updatedAt,
  });
}

/// One in-progress session per scenario_key, read from
/// `users/{uid}/scenarios/*` — the collection scenario_engine.py's
/// `update_scenario_state` writes `current_step` and the full
/// `session_state` (including `session_state.data.difficulty`) to on every
/// turn.
Map<String, InProgressScenario> parseInProgressScenarios(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final result = <String, InProgressScenario>{};
  for (final doc in docs) {
    final data = doc.data();
    final currentStep = (data['current_step'] ?? '').toString();
    // 'complete' is the one step value scenario_engine.py sets once the
    // player actually dismisses the finished-scenario screen (tapping
    // "Close" on scene7_dashboard) — everything else, including
    // scene7_dashboard itself, is still "in progress" as far as resuming
    // goes, but scene7_dashboard specifically means the interactive part
    // is already done, so it's excluded below via sceneForStep instead.
    if (currentStep.isEmpty || currentStep == 'complete') continue;

    final sessionState = data['session_state'];
    final sessionData = sessionState is Map ? sessionState['data'] : null;
    final scenarioKey = sessionData is Map
        ? sessionData['scenario_key']?.toString()
        : null;
    if (scenarioKey == null || scenarioKey.isEmpty) continue;

    final scene = sceneForStep(currentStep);
    if (scene == SceneId.dashboard) continue;
    // ScenarioPlayPage.initState() calls provider.start() the instant a
    // scenario's intro screen is opened — before "Begin Scenario" is
    // ever tapped — which immediately persists a session sitting at
    // scene0_greet (SceneId.preScene, ordinal 0). Counting that as "in
    // progress" made every scenario a user had merely glanced at (then
    // backed out of) show a stray "0% complete"/"Easy Mode" pill, even
    // though nothing was actually played yet.
    if (scene == SceneId.preScene) continue;

    final difficulty = sessionData is Map
        ? sessionData['difficulty']?.toString()
        : null;
    // A brand-new session (e.g. right after "Start Over") only has
    // create_scenario's `created_at` — `updated_at` isn't written until
    // the first real step transition — so comparing on `updated_at`
    // alone left a fresh session's doc with no timestamp to compare,
    // which meant Firestore's arbitrary doc ordering could pick a stale
    // abandoned session over it and show its old progress% instead of
    // resetting to 0%. Falling back to `created_at` guarantees every
    // session doc has a real, comparable timestamp.
    final updatedAt =
        DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
        DateTime.tryParse(data['created_at']?.toString() ?? '');

    // A scenario_key can have more than one session doc (e.g. replayed
    // after finishing once before) — keep whichever was updated most
    // recently for that key.
    final existing = result[scenarioKey];
    if (existing != null &&
        existing.updatedAt != null &&
        updatedAt != null &&
        existing.updatedAt!.isAfter(updatedAt)) {
      continue;
    }

    result[scenarioKey] = InProgressScenario(
      progress: sceneOrdinal(scene) / 7,
      isDifficult: difficulty == 'difficult',
      updatedAt: updatedAt,
    );
  }
  return result;
}
