import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../emotiondetection/themed_scenario/scenario_models.dart';
import '../../emotiondetection/themed_scenario/scenario_play_page.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key, this.gridKey});

  /// Spotlight target for the dashboard tour's "Ranked For You" step.
  final Key? gridKey;

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  // Created once (not inline in build()) so a rebuild triggered by
  // something unrelated — typing in the search box, the dashboard tour,
  // DraggableScrollableSheet drags elsewhere in the tree, anything that
  // calls setState — doesn't tear down and recreate the Firestore stream.
  // Recreating it on every rebuild made the "X% complete"/difficulty pill
  // flash back to its FutureBuilder/StreamBuilder loading state and briefly
  // show stale/no data each time, which read as the percentage "not
  // updating in real time" even though the underlying data was live.
  late final Future<Map<String, double>> _themeAveragesFuture =
      _loadThemeAverages();
  late final Stream<Map<String, _InProgressInfo>> _inProgressStream =
      _watchInProgressScenarios();
  late final Stream<Map<String, bool>> _difficultyStream =
      _watchScenarioDifficulty();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, double>> _loadThemeAverages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('spinAssessments')
        .doc('initial')
        .get();

    if (!doc.exists) return {};

    final raw = doc.data()?['themeAverages'];
    if (raw is! Map) return {};

    final result = <String, double>{};
    raw.forEach((key, value) {
      if (value is num) {
        result[key.toString()] = value.toDouble();
      }
    });
    return result;
  }

  /// One in-progress session per scenario_key, read straight from
  /// `users/{uid}/scenarios/*` — the same collection scenario_engine.py's
  /// `update_scenario_state` writes `current_step` and the full
  /// `session_state` (including `session_state.data.difficulty`) to on
  /// every turn. No backend change needed: this is exactly the data the
  /// "Resume Scenario?" dialog already relies on being there.
  ///
  /// A live `.snapshots()` listener (not a one-shot `.get()`) so the
  /// progress/difficulty badge updates the moment a step actually changes
  /// server-side, instead of only refreshing whenever this screen happens
  /// to rebuild — that one-shot version left the badge showing whatever it
  /// was at the last time this screen was freshly mounted, not the
  /// player's actual current progress.
  Stream<Map<String, _InProgressInfo>> _watchInProgressScenarios() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const {});

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scenarios')
        .snapshots()
        .map(_parseInProgressScenarios);
  }

  Map<String, _InProgressInfo> _parseInProgressScenarios(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final result = <String, _InProgressInfo>{};
    for (final doc in snapshot.docs) {
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
      // backed out of) show a stray "0% complete"/"Easy Mode" pill here,
      // even though nothing was actually played yet.
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

      result[scenarioKey] = _InProgressInfo(
        progress: sceneOrdinal(scene) / 7,
        isDifficult: difficulty == 'difficult',
        updatedAt: updatedAt,
      );
    }
    return result;
  }

  /// Which difficulty mode a scenario_key's NEXT attempt would auto-run in,
  /// per scenario_key — shown on every card regardless of whether the user
  /// has ever opened that scenario, so "what mode is this currently in" is
  /// visible up front rather than only appearing once a session exists.
  /// Mirrors scenario_engine.py's `_decide_difficulty` exactly, reading the
  /// same `users/{uid}/scenario_progress/{scenarioKey}` docs it writes via
  /// `mark_scenario_difficulty_completed`: neither mode completed -> Easy;
  /// Easy completed, Difficult not -> Difficult; both completed -> Easy
  /// (matching the backend's picker-shown default).
  Stream<Map<String, bool>> _watchScenarioDifficulty() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const {});

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scenario_progress')
        .snapshots()
        .map(_parseScenarioDifficulty);
  }

  Map<String, bool> _parseScenarioDifficulty(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final result = <String, bool>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final easyDone = data['easy_completed'] == true;
      final difficultDone = data['difficult_completed'] == true;
      result[doc.id] = easyDone && !difficultDone;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF0B28D9),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HATI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Practice Scenarios',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(64),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search',
                          hintStyle: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 0,
                          ),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 0,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              transform: Matrix4.translationValues(0, -20, 0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _recentActivityCard(context),
                    const SizedBox(height: 22),
                    const Text(
                      'Scenario Modules',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, double>>(
                      future: _themeAveragesFuture,
                      builder: (context, themeSnapshot) {
                        if (themeSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final themeAverages = themeSnapshot.data ?? {};
                        // Live-streamed (not a one-shot fetch) so the
                        // progress %/difficulty badge updates the moment
                        // the player advances a step, even while this
                        // screen stays mounted underneath ScenarioPlayPage.
                        return StreamBuilder<Map<String, _InProgressInfo>>(
                          stream: _inProgressStream,
                          builder: (context, inProgressSnapshot) {
                            final inProgress =
                                inProgressSnapshot.data ?? const {};
                            return StreamBuilder<Map<String, bool>>(
                              stream: _difficultyStream,
                              builder: (context, difficultySnapshot) {
                                final difficulty =
                                    difficultySnapshot.data ?? const {};
                                return _scenarioGrid(
                                  context,
                                  themeAverages,
                                  inProgress,
                                  difficulty,
                                  query: _query,
                                  firstCardKey: widget.gridKey,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _recentActivityCard(BuildContext context) {
  const defaultTheme = '';
  const defaultKey = '';

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const SizedBox.shrink();
  }

  final stream = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('spinAssessments')
      .doc('initial')
      .snapshots();

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          height: 150,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final doc = snapshot.data;
      final raw = doc?.data()?['lastScenario'];
      if (raw == null) {
        // No scenario started yet — leave this blank instead of showing a
        // placeholder card with nothing real to say.
        return const SizedBox(height: 4);
      }

      final scenarioTitle =
          (raw['scenarioTitle'] as String? ?? 'Pick a scenario').toString();
      final scenarioTheme = (raw['scenarioTheme'] as String? ?? defaultTheme)
          .toString();
      final scenarioKey = (raw['scenarioKey'] as String? ?? defaultKey)
          .toString();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0B28D9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenarioTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hop back in with Hati!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      await _saveLastScenario(
                        scenarioTitle: scenarioTitle,
                        scenarioTheme: scenarioTheme,
                        scenarioKey: scenarioKey,
                      );

                      if (!context.mounted) return;
                      if (scenarioKey.isEmpty) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScenarioPlayPage(
                            scenarioTitle: scenarioTitle,
                            scenarioTheme: scenarioTheme,
                            scenarioKey: scenarioKey,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF0BA2D9),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Continue',
                            style: TextStyle(
                              color: Color(0xFF0BA2D9),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 84,
                height: 84,
                color: const Color(0xFFF0F3FF),
                child: Image.asset(
                  _placeholderAssetForScenario(scenarioKey),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _InProgressPill extends StatelessWidget {
  final String label;
  final Color color;

  const _InProgressPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Progress through an unfinished session for one scenario_key — see
/// [_ModulesScreenState._loadInProgressScenarios].
class _InProgressInfo {
  final double progress;
  final bool isDifficult;
  final DateTime? updatedAt;

  const _InProgressInfo({
    required this.progress,
    required this.isDifficult,
    this.updatedAt,
  });
}

class _ScenarioTemplate {
  final String theme;
  final String scenarioKey;
  final String title;

  const _ScenarioTemplate({
    required this.theme,
    required this.scenarioKey,
    required this.title,
  });
}

/// SPIN sometimes stores "Embarassment" (one r); Firestore keys must still match %.
double _matchPercent(Map<String, double> themeAverages, String backendTheme) {
  switch (backendTheme) {
    case 'Fear of Negative Evaluation & Embarrassment':
      return themeAverages['Fear of Negative Evaluation & Embarrassment'] ??
          themeAverages['Fear of Negative Evaluation & Embarassment'] ??
          0;
    default:
      return themeAverages[backendTheme] ?? 0;
  }
}

Future<Map<String, dynamic>?> _loadLastScenario() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('spinAssessments')
      .doc('initial')
      .get();

  final raw = doc.data()?['lastScenario'];
  if (raw is Map) {
    return raw.cast<String, dynamic>();
  }
  return null;
}

Future<void> _saveLastScenario({
  required String scenarioTitle,
  required String scenarioTheme,
  required String scenarioKey,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('spinAssessments')
      .doc('initial')
      .set({
        'lastScenario': {
          'scenarioTitle': scenarioTitle,
          'scenarioTheme': scenarioTheme,
          'scenarioKey': scenarioKey,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
}

/// One module per SPIN theme; `scenarioKey` must match `THEME_SCENARIO_KEYS` in `scenario_engine.py`.
/// `foa_classroom` ("WHERE TO SIT?") is intentionally omitted from this
/// list — hidden from the Modules grid, though still fully functional
/// server-side if ever navigated to directly.
const List<_ScenarioTemplate> _kAllScenarioModules = [
  _ScenarioTemplate(
    theme: 'Fear of Authority',
    scenarioKey: 'foa_supervisor',
    title: "The Professor's Request",
  ),
  _ScenarioTemplate(
    theme: 'Fear of Strangers & New People',
    scenarioKey: 'fsn_seat',
    title: "The Food Hall's Seat",
  ),
  _ScenarioTemplate(
    theme: 'Fear of Being Observed & Performing',
    scenarioKey: 'fbop_spotlight',
    title: 'Project Defense: Defended or Offended',
  ),
  _ScenarioTemplate(
    theme: 'Fear of Social Gatherings',
    scenarioKey: 'fsg_party',
    title: 'The Student Gathering: To Approach or Not?',
  ),
  _ScenarioTemplate(
    theme: 'Fear of Negative Evaluation & Embarrassment',
    scenarioKey: 'fne_stage',
    title: 'The Group Project: Defending Your Work',
  ),
  _ScenarioTemplate(
    theme: 'Physiological Symptoms',
    scenarioKey: 'phys_jeepney',
    title: 'The Jeep Stop: Hiding Visible Anxiety',
  ),
];

List<_ScenarioTemplate> _buildScenarioTemplates(
  Map<String, double> themeAverages,
) {
  return List<_ScenarioTemplate>.from(_kAllScenarioModules)
    ..sort(
      (a, b) => _matchPercent(
        themeAverages,
        b.theme,
      ).compareTo(_matchPercent(themeAverages, a.theme)),
    );
}

/// The Modules grid's own thumbnail art — separate from the full-screen
/// background used during scenario play (see assets/scenario_placeholder/).
String _placeholderAssetForScenario(String scenarioKey) {
  return kScenarioConfigs[scenarioKey]?.placeholderAsset ??
      kScenarioConfigs['foa_supervisor']!.placeholderAsset;
}

bool _matchesQuery(_ScenarioTemplate template, String query) {
  if (query.isEmpty) return true;
  final needle = query.toLowerCase();
  return template.title.toLowerCase().contains(needle) ||
      template.theme.toLowerCase().contains(needle);
}

Widget _scenarioGrid(
  BuildContext context,
  Map<String, double> themeAverages,
  Map<String, _InProgressInfo> inProgress,
  Map<String, bool> difficulty, {
  String query = '',
  Key? firstCardKey,
}) {
  final templates = _buildScenarioTemplates(
    themeAverages,
  ).where((template) => _matchesQuery(template, query)).toList();

  if (templates.isEmpty) {
    return Padding(
      key: firstCardKey,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No modules match "$query".',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black45, fontSize: 13.5),
        ),
      ),
    );
  }

  return Column(
    children: List.generate(templates.length, (index) {
      final template = templates[index];
      final score = _matchPercent(themeAverages, template.theme);
      final info = inProgress[template.scenarioKey];
      // A genuinely in-progress session's own recorded difficulty wins
      // (it's the mode that attempt is actually running in); otherwise
      // fall back to the predicted next-attempt mode from scenario_progress.
      final isDifficult =
          info?.isDifficult ?? (difficulty[template.scenarioKey] ?? false);
      return Padding(
        key: index == 0 ? firstCardKey : null,
        padding: EdgeInsets.only(
          bottom: index == templates.length - 1 ? 0 : 14,
        ),
        child: GestureDetector(
          onTap: () async {
            await _saveLastScenario(
              scenarioTitle: template.title,
              scenarioTheme: template.theme,
              scenarioKey: template.scenarioKey,
            );
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScenarioPlayPage(
                  scenarioTitle: template.title,
                  scenarioTheme: template.theme,
                  scenarioKey: template.scenarioKey,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 84,
                    height: 84,
                    // Placeholder art isn't square (tall rectangular
                    // illustrations) — contain + a neutral fill shows the
                    // full picture, letterboxed, instead of cropping into it.
                    color: const Color(0xFFF0F3FF),
                    child: Image.asset(
                      _placeholderAssetForScenario(template.scenarioKey),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        template.theme,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black45,
                          height: 1.3,
                        ),
                      ),
                      // The difficulty pill always shows — which mode a
                      // fresh attempt would auto-run in (or, if a session
                      // is genuinely in progress, that attempt's actual
                      // difficulty instead) — so the user knows what mode
                      // a scenario is currently in before ever opening it.
                      // "% complete" only shows once a session is truly in
                      // progress (real advancement past the FSM's shared
                      // 7-scene numbering — see sceneOrdinal).
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (info != null)
                            _InProgressPill(
                              label: '${(info.progress * 100).round()}% complete',
                              color: const Color(0xFF0B28D9),
                            ),
                          _InProgressPill(
                            label: isDifficult ? 'Hard Mode' : 'Easy Mode',
                            color: isDifficult
                                ? const Color(0xFFC62828)
                                : const Color(0xFF2E7D32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${score.round()}% match',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B28D9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }),
  );
}
