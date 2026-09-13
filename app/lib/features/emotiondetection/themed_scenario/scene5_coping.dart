// ─────────────────────────────────────────────
// HATI – Scene 5: Coping Strategy Integration
// screens/scene5_coping.dart
//
// Adapted from testing_env/lib/scene5_coping.dart (which also held
// Scene6Closing — kept together here for the same reason). Backend steps
// `scene5_coping` / `scene5_coping_done` map to this scene.
//
// Per the approved plan: the "Yes / Maybe later / No" tap and the final
// "I'm done" tap are the only two points that hit the backend. The 5-step
// grounding walkthrough itself (_PracticeWalkthrough) is client-only —
// scenario_engine.py never sees or needs those intermediate substeps.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

class Scene5Coping extends StatefulWidget {
  const Scene5Coping({super.key});

  @override
  State<Scene5Coping> createState() => _Scene5CopingState();
}

class _Scene5CopingState extends State<Scene5Coping> {
  String? _trackedStep;
  bool _dialogueComplete = false;
  // 'scene5_coping_done' no longer carries the tool text in its own
  // messages (the backend's reply there is just "Great. Try it now.") —
  // remembered here from the prior 'scene5_coping' step so the walkthrough
  // can actually reflect whichever strategy was assigned (Anchor, Reframe,
  // Savoring, ...) instead of always showing a generic grounding script.
  String _lastToolText = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final config = provider.config;
    final step = provider.backendStep;
    final parsedTexts = provider.messages
        .map(parseSpeakerMessage)
        .map((m) => m.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();

    if (step != _trackedStep) {
      _trackedStep = step;
      _dialogueComplete = false;
    }

    Widget? body;
    Widget? bottomBar;
    String persistentMessage;

    if (step == 'scene5_coping_done') {
      persistentMessage = parsedTexts.join('\n\n');
      body = _PracticeWalkthrough(
        key: const ValueKey('practice'),
        strategy: _lastToolText,
        isLoading: provider.isLoading,
        onFinished: () => provider.submitText(
          provider.ui.options.isNotEmpty
              ? provider.ui.options.first
              : "I'm done",
        ),
      );
    } else {
      // scene5_coping: messages = [intro, tool, "Do you want to try..."].
      final introText = parsedTexts.isNotEmpty ? parsedTexts.first : '';
      final questionText = parsedTexts.length >= 3 ? parsedTexts.last : '';
      final toolText = parsedTexts.length >= 2
          ? parsedTexts[1]
          : (parsedTexts.isNotEmpty ? parsedTexts.last : '');
      persistentMessage = [
        introText,
        questionText,
      ].where((s) => s.isNotEmpty).join('\n\n');
      if (toolText.isNotEmpty) _lastToolText = toolText;
      body = _CopingStrategyCard(key: ValueKey(step), strategy: toolText);
      bottomBar = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in provider.ui.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: opt.toLowerCase() == 'yes'
                  ? HatiButton(
                      label: opt,
                      icon: Icons.play_circle_rounded,
                      onTap: provider.isLoading
                          ? null
                          : () => provider.submitText(opt),
                    )
                  : HatiOutlineButton(
                      label: opt,
                      onTap: provider.isLoading
                          ? () {}
                          : () => provider.submitText(opt),
                    ),
            ),
        ],
      );
    }

    // Body/input stay out of the tree — not just disabled — until Hati's
    // coach line for this step has fully typed out, then pop in.
    body = popInIfReady(body, ready: _dialogueComplete, stepKey: step ?? '');
    bottomBar = popInIfReady(
      bottomBar,
      ready: _dialogueComplete,
      stepKey: step ?? '',
    );

    return Scaffold(
      body: ScenarioGradientBackground(
        backgroundAsset: config.backgroundAsset,
        child: Column(
          children: [
            const SceneTopHeader(
              currentStep: 5,
              totalSteps: 7,
              sceneLabel: 'Coping Strategy Integration',
            ),
            const SceneSpeedToggleRow(),
            Expanded(
              child: HatiSceneShell(
                showCoach: true,
                persistentMessage: persistentMessage,
                mood: HatiMood.thinking,
                onSequenceComplete: () {
                  if (mounted && !_dialogueComplete) {
                    setState(() => _dialogueComplete = true);
                  }
                },
                body: body,
                bottomBar: bottomBar,
                // Only white once the body is actually showing — otherwise
                // this left a blank white box sitting there for the whole
                // time Hati was still typing.
                contentBackgroundColor: _dialogueComplete ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopingStrategyCard extends StatelessWidget {
  final String strategy;

  const _CopingStrategyCard({super.key, required this.strategy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🛡️', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your Coping Strategy',
                  style: HatiTextStyles.heading3.copyWith(
                    color: HatiColors.mossGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(strategy, style: HatiTextStyles.bodyLarge),
        ],
      ),
    );
  }
}

/// Client-only practice walkthrough. Not driven by the backend — the
/// backend only expects to hear "I'm done" once this completes. [strategy]
/// is whichever tool text `_scene5_coping` actually assigned (Anchor,
/// Reframe, Savoring, grounding, ...) — the first step below surfaces that
/// exact text instead of a generic script, so the walkthrough always
/// matches what Hati said the strategy was, whatever it happened to be.
class _PracticeWalkthrough extends StatefulWidget {
  final String strategy;
  final bool isLoading;
  final VoidCallback onFinished;

  const _PracticeWalkthrough({
    super.key,
    required this.strategy,
    required this.isLoading,
    required this.onFinished,
  });

  @override
  State<_PracticeWalkthrough> createState() => _PracticeWalkthroughState();
}

class _PracticeWalkthroughState extends State<_PracticeWalkthrough> {
  late final List<String> _steps = [
    widget.strategy.isNotEmpty
        ? widget.strategy
        : 'Take a moment to settle in with the strategy Hati just gave you.',
    'Take a slow breath in for 4 counts... hold for 2... out for 6.',
    'Now say your first line silently in your head three times.',
    "Good. That's the skill—carry it with you.",
  ];

  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🧘 Practice Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: HatiColors.mossGreen,
                ),
              ),
              Text(
                '${_step + 1} / ${_steps.length}',
                style: HatiTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (_step + 1) / _steps.length,
            color: HatiColors.mossGreen,
            backgroundColor: HatiColors.divider,
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Container(
              key: ValueKey(_step),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HatiColors.mossGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_steps[_step], style: HatiTextStyles.bodyLarge),
            ),
          ),
          const SizedBox(height: 12),
          HatiButton(
            label: _step < _steps.length - 1
                ? 'Done, next step'
                : 'Finish Practice',
            icon: _step < _steps.length - 1
                ? Icons.arrow_forward_rounded
                : Icons.check_circle_rounded,
            onTap: widget.isLoading
                ? null
                : () {
                    if (_step < _steps.length - 1) {
                      setState(() => _step++);
                    } else {
                      widget.onFinished();
                    }
                  },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HATI – Scene 6: Closing
// screens/scene6_closing.dart
// ─────────────────────────────────────────────

class Scene6Closing extends StatefulWidget {
  const Scene6Closing({super.key});

  @override
  State<Scene6Closing> createState() => _Scene6ClosingState();
}

class _Scene6ClosingState extends State<Scene6Closing> {
  bool _dialogueComplete = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final parsed = provider.messages
        .map(parseSpeakerMessage)
        .map((m) => m.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    // messages = ["Here's what I want you to remember:", insight, closing line]
    final insight = parsed.length >= 2
        ? parsed[1]
        : (parsed.isNotEmpty ? parsed.first : '');
    final closingLine = parsed.isNotEmpty
        ? parsed.last
        : "You showed up today. That's a win.";
    final finishLabel = provider.ui.options.isNotEmpty
        ? provider.ui.options.first
        : 'Finish';

    return Scaffold(
      body: HatiTapToAdvance(
        child: Stack(
        children: [
          // Brand blue (0xFF0B28D9) — same header color as the Progress
          // and Profile screens — rather than the scenario's usual green,
          // since this is the "you're done" completion screen, not
          // in-scenario dialogue.
          Container(color: const Color(0xFF0B28D9)),
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  const SceneProgressBar(
                    currentStep: 6,
                    totalSteps: 7,
                    sceneLabel: 'Closing',
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: HatiColors.softGold.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: HatiColors.softGold.withValues(
                                  alpha: 0.5,
                                ),
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Text('🏆', style: TextStyle(fontSize: 40)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: HatiColors.softGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: HatiColors.softGold.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: const Text(
                              'SCENARIO COMPLETE!',
                              style: TextStyle(
                                color: HatiColors.softGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '💡 What to remember:',
                                  style: TextStyle(
                                    color: HatiColors.mintFresh,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  insight,
                                  textAlign: TextAlign.center,
                                  style: HatiTextStyles.bodyLarge.copyWith(
                                    color: HatiColors.warmCream,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          HatiSpeakingBlock(
                            persistentMessage: closingLine,
                            frogSize: 150,
                            mood: HatiMood.happy,
                            onSequenceComplete: () {
                              if (mounted && !_dialogueComplete) {
                                setState(() => _dialogueComplete = true);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  // Stays out of the tree — not just disabled — until the
                  // closing line has fully typed out, then pops in.
                  if (_dialogueComplete)
                    PopIn(
                      key: const ValueKey('finish-button'),
                      child: HatiButton(
                        label: finishLabel,
                        icon: Icons.check_rounded,
                        color: HatiColors.leafGreen,
                        onTap: provider.isLoading
                            ? null
                            : () => provider.submitText(finishLabel),
                      ),
                    )
                  else
                    const SizedBox(height: 52),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
