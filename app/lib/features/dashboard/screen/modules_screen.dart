import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../emotiondetection/themed_scenario/scenario_models.dart';
import '../../emotiondetection/themed_scenario/scenario_play_page.dart';

class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

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
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
                      future: _loadThemeAverages(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final themeAverages = snapshot.data ?? {};
                        return _scenarioGrid(context, themeAverages);
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
    title: "The Professor's Signature",
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
    title: 'The House Party: To Approach or Not?',
  ),
  _ScenarioTemplate(
    theme: 'Fear of Negative Evaluation & Embarrassment',
    scenarioKey: 'fne_stage',
    title: 'The Group Project: Defending Your Work',
  ),
  _ScenarioTemplate(
    theme: 'Physiological Symptoms',
    scenarioKey: 'phys_jeepney',
    title: 'The Bus Stop: Hiding Visible Anxiety',
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

Widget _scenarioGrid(BuildContext context, Map<String, double> themeAverages) {
  final templates = _buildScenarioTemplates(themeAverages);

  return Column(
    children: List.generate(templates.length, (index) {
      final template = templates[index];
      final score = _matchPercent(themeAverages, template.theme);
      return Padding(
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
