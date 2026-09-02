// ─────────────────────────────────────────────
// HATI – Scene 0: Pre-Scene Setup
// screens/scene0_pre_setup.dart
//
// Adapted from testing_env/lib/scene0_pre_setup.dart: the greeting text and
// the "Begin" button label/action now come from ScenarioProvider.messages /
// ui.options (backend step `scene0_greet`) instead of hardcoded strings and
// a local goToScene() call.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

/// Set once the first time a player reaches any scenario's Scene 0, so the
/// walkthrough dialog only ever shows once per device.
const _kScenarioTutorialSeenKey = 'hati_scenario_tutorial_seen';

class Scene0PreSetup extends StatefulWidget {
  const Scene0PreSetup({super.key});

  @override
  State<Scene0PreSetup> createState() => _Scene0PreSetupState();
}

class _Scene0PreSetupState extends State<Scene0PreSetup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // Hati's intro dialogue plays as a multi-step typewriter sequence
  // (see HatiSpeakingBlock/onSequenceComplete). Don't let the player
  // advance past this scene until every line has actually been shown,
  // otherwise the later lines get torn down mid-animation.
  bool _dialogueComplete = false;

  // Null while the one-time device check is still loading; false shows the
  // walkthrough dialog and holds Hati's dialogue back until it's dismissed;
  // true means it was already seen (or was just dismissed) and Hati is
  // free to start talking.
  bool? _tutorialSeen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _maybeShowTutorial();
  }

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(_kScenarioTutorialSeenKey) ?? false) {
      setState(() => _tutorialSeen = true);
      return;
    }
    setState(() => _tutorialSeen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial(prefs));
  }

  Future<void> _showTutorial(SharedPreferences prefs) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ScenarioTutorialDialog(
        onGotIt: () => Navigator.pop(context),
      ),
    );
    await prefs.setBool(_kScenarioTutorialSeenKey, true);
    if (mounted) setState(() => _tutorialSeen = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final config = provider.config;

    final parsed = provider.messages
        .map(parseSpeakerMessage)
        .map((m) => m.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();

    String introMessage = '';
    String persistentMessage = '';
    if (parsed.length == 1) {
      persistentMessage = parsed.first;
    } else if (parsed.length > 1) {
      introMessage = parsed.first;
      persistentMessage = parsed.sublist(1).join('\n\n');
    }

    final canBegin =
        provider.ui.type == ScenarioUIType.buttons && provider.ui.options.isNotEmpty;
    final beginLabel = canBegin ? provider.ui.options.first : 'Begin Scenario';
    final readyToBegin = canBegin && _dialogueComplete;

    return Scaffold(
      body: HatiTapToAdvance(
        child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [HatiColors.deepForest, Color(0xFF2A4A2A)],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HatiColors.mossGreen.withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HatiColors.leafGreen.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 24,
                            ),
                            child: Column(
                              children: [
                                // Top badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: HatiColors.leafGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: HatiColors.leafGreen.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    config.theme.toUpperCase(),
                                    style: const TextStyle(
                                      color: HatiColors.mintFresh,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: HatiSpeedToggle(),
                                ),

                                const Spacer(),

                                // Scenario title
                                Text(
                                  config.title,
                                  textAlign: TextAlign.center,
                                  style: HatiTextStyles.heading1.copyWith(
                                    color: HatiColors.warmCream,
                                    fontSize: 26,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                if (parsed.isEmpty || _tutorialSeen == null)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(
                                      color: HatiColors.mintFresh,
                                    ),
                                  )
                                else if (_tutorialSeen == false)
                                  // Hati waits quietly until the walkthrough
                                  // dialog above is dismissed.
                                  const HatiFrogAvatar(size: 180)
                                else
                                  HatiSpeakingBlock(
                                    introMessage: introMessage,
                                    persistentMessage: persistentMessage,
                                    frogSize: 180,
                                    onSequenceComplete: () {
                                      if (mounted && !_dialogueComplete) {
                                        setState(() => _dialogueComplete = true);
                                      }
                                    },
                                  ),

                                const Spacer(),

                                // Begin button
                                HatiButton(
                                  label: beginLabel,
                                  icon: Icons.play_arrow_rounded,
                                  onTap: (!readyToBegin || provider.isLoading)
                                      ? null
                                      : () => provider.submitText(beginLabel),
                                  color: HatiColors.leafGreen,
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Back to Dashboard',
                                    style: HatiTextStyles.bodyMedium.copyWith(
                                      color: HatiColors.warmCream.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── First-time scenario walkthrough ─────────────────────────────────────────
/// Shown once ever (see [_kScenarioTutorialSeenKey]) before Hati's greeting
/// starts, so the player knows the scenario unfolds across multiple scenes
/// and that tapping anywhere on screen is what advances Hati's dialogue.
class _ScenarioTutorialDialog extends StatelessWidget {
  final VoidCallback onGotIt;

  const _ScenarioTutorialDialog({required this.onGotIt});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: HatiColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HatiColors.deepForest, HatiColors.mossGreen],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: HatiColors.softGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'How This Scenario Works',
                      style: HatiTextStyles.heading3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TutorialStepRow(
                    icon: Icons.view_carousel_rounded,
                    title: 'Multiple scenes',
                    description:
                        'This scenario plays out across several scenes, one '
                        'after another — each builds on what happened '
                        'before.',
                  ),
                  const SizedBox(height: 16),
                  _TutorialStepRow(
                    icon: Icons.touch_app_rounded,
                    title: 'Tap to continue',
                    description:
                        "Whenever Hati is talking, tap anywhere on the "
                        "screen to hear the next line — or tap again to "
                        "skip ahead while it's still typing.",
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: HatiButton(
                  label: 'Got it',
                  icon: Icons.check_rounded,
                  color: HatiColors.mossGreen,
                  onTap: onGotIt,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialStepRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TutorialStepRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: HatiColors.mossGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: HatiColors.mossGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: HatiTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HatiColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: HatiTextStyles.bodyMedium.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
