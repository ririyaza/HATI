import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../emotiondetection/scenario_game.dart';

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HATI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 14),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
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
                        if (snapshot.connectionState == ConnectionState.waiting) {
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
  const defaultTitle = '';
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
          height: 170,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final doc = snapshot.data;
      final raw = doc?.data()?['lastScenario'];
      final scenarioTitle =
      (raw?['scenarioTitle'] as String? ?? defaultTitle).toString();
      final scenarioTheme =
      (raw?['scenarioTheme'] as String? ?? defaultTheme).toString();
      final scenarioKey =
      (raw?['scenarioKey'] as String? ?? defaultKey).toString();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B28D9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(_backgroundAssetForScenario(scenarioKey)),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.22),
                              Colors.black.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      scenarioTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        await _saveLastScenario(
                          scenarioTitle: scenarioTitle,
                          scenarioTheme: scenarioTheme,
                          scenarioKey: scenarioKey,
                        );

                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmotionPage(
                              scenarioTitle: scenarioTitle,
                              scenarioTheme: scenarioTheme,
                              scenarioKey: scenarioKey,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            color: Color(0xFF0BA2D9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
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

const _whereToSitModule = _ScenarioTemplate(
  theme: 'Fear of Authority',
  scenarioKey: 'foa_classroom',
  title: 'WHERE TO SIT?',
);

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
      .set(
    {
      'lastScenario': {
        'scenarioTitle': scenarioTitle,
        'scenarioTheme': scenarioTheme,
        'scenarioKey': scenarioKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    },
    SetOptions(merge: true),
  );
}

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
    scenarioKey: 'phys_classroom',
    title: 'The Bus Stop: Hiding Visible Anxiety',
  ),
];

List<_ScenarioTemplate> _buildScenarioTemplates(Map<String, double> themeAverages) {
  final ranked = List<_ScenarioTemplate>.from(_kAllScenarioModules)
    ..sort(
          (a, b) => _matchPercent(themeAverages, b.theme)
          .compareTo(_matchPercent(themeAverages, a.theme)),
    );
  return [...ranked, _whereToSitModule];
}

String _backgroundAssetForScenario(String scenarioKey) {
  const assets = {
    'foa_supervisor': 'assets/images/Scenario/foa_bg.jpg',
    'foa_classroom': 'assets/images/Scenario/fosnp_bg_2.jpg',
    'fsn_seat': 'assets/images/Scenario/fosnp_bg.jpg',
    'fbop_spotlight': 'assets/images/Scenario/fobap_bg.jpg',
    'fsg_party': 'assets/images/Scenario/fosg_bg.jpg',
    'fne_stage': 'assets/images/Scenario/fonae_bg.jpg',
    'phys_classroom': 'assets/images/Scenario/phys_bg.jpg',
  };
  return assets[scenarioKey] ?? 'assets/images/Scenario/foa_bg.jpg';
}

Widget _scenarioGrid(BuildContext context, Map<String, double> themeAverages) {
  final templates = _buildScenarioTemplates(themeAverages);

  return GridView.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.84,
    ),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: templates.length,
    itemBuilder: (context, index) {
      final template = templates[index];
      final score = _matchPercent(themeAverages, template.theme);
      return GestureDetector(
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
              builder: (context) => EmotionPage(
                scenarioTitle: template.title,
                scenarioTheme: template.theme,
                scenarioKey: template.scenarioKey,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                      image: DecorationImage(
                        image:
                        AssetImage(_backgroundAssetForScenario(template.scenarioKey)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.32),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.14),
                          Colors.black.withOpacity(0.45),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${score.round()}% match',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withAlpha(170),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
