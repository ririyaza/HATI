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

import 'dart:async';

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
  // Remembers whether the player answered "Yes" to trying the coping
  // strategy (a positive branch) vs "Maybe later"/"No", so Hati's mood
  // below can react to it once the answer's been given — null (default
  // thinking mood) until they've actually tapped one of the three.
  bool? _lastAnswerPositive;
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

    if (step == 'scene5_coping_done' || step == 'scene5_coping_pref_wait') {
      persistentMessage = parsedTexts.join('\n\n');
      body = _PracticeWalkthrough(
        key: const ValueKey('practice'),
        // scene5_coping_pref_wait's single message ("Go ahead and try this
        // now: X. Take your time...") IS the strategy text — there's no
        // separate _lastToolText for it since this path skips the
        // theme/story_branch tool entirely (see _enter_scene5_coping in
        // scenario_engine.py).
        strategy: step == 'scene5_coping_pref_wait'
            ? parsedTexts.join(' ')
            : _lastToolText,
        isLoading: provider.isLoading,
        onFinished: () => provider.submitText(
          provider.ui.options.isNotEmpty
              ? provider.ui.options.first
              : "I'm done",
        ),
      );
    } else if (step == 'scene5_coping_pref_pick') {
      // User has more than one onboarding coping preference on file —
      // let them pick which one to do right now.
      persistentMessage = parsedTexts.join('\n\n');
      bottomBar = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in provider.ui.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: HatiOutlineButton(
                label: opt,
                onTap: provider.isLoading
                    ? () {}
                    : () => provider.submitText(opt),
              ),
            ),
        ],
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
                          : () {
                              setState(() => _lastAnswerPositive = true);
                              provider.submitText(opt);
                            },
                    )
                  : HatiOutlineButton(
                      label: opt,
                      onTap: provider.isLoading
                          ? () {}
                          : () {
                              setState(() => _lastAnswerPositive = false);
                              provider.submitText(opt);
                            },
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
                // Once the player has answered, react to which way it
                // branched — "Yes" (trying the strategy) is the positive
                // branch and gets Hati's happy mood; "Maybe later"/"No"
                // keeps the default thinking mood, same as before any
                // answer's been given.
                mood: _lastAnswerPositive == true
                    ? HatiMood.happy
                    : HatiMood.thinking,
                onSequenceComplete: () {
                  if (mounted && !_dialogueComplete) {
                    setState(() => _dialogueComplete = true);
                  }
                },
                showIdleReminder: !_dialogueComplete,
                body: body,
                bottomBar: bottomBar,
                // Only white once the body is actually showing — otherwise
                // this left a blank white box sitting there for the whole
                // time Hati was still typing.
                contentBackgroundColor: _dialogueComplete
                    ? const Color(0xFFF5F1E8)
                    : null,
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

/// Splits one approved strategy paragraph into sequential Practice Mode
/// steps, purely by sentence boundary — no wording is added or changed.
/// e.g. "Savor and Repeat. Think back to the moment it went well — what
/// did you do? Remember that, and use the same approach again." becomes
/// three steps, each the exact same text Hati already said, just paced
/// out one at a time instead of shown all at once.
///
/// A sentence boundary is "." / "!" / "?" followed by whitespace and then
/// an uppercase letter or digit — the whitespace+uppercase lookahead is
/// what keeps an ellipsis ("...") or a mid-sentence abbreviation from
/// being split early. Falls back to the whole string as a single step
/// when there's nothing to split on (one sentence, or empty text), which
/// matches this widget's previous behavior exactly.
List<String> _splitStrategyIntoSteps(String strategy) {
  final trimmed = strategy.trim();
  if (trimmed.isEmpty) {
    return const [
      'Take a moment to settle in with the strategy Hati just gave you.',
    ];
  }
  final parts = trimmed
      .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9])'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return parts.isNotEmpty ? parts : [trimmed];
}

/// Client-only practice walkthrough. Not driven by the backend — the
/// backend only expects to hear "I'm done" once this completes. [strategy]
/// is whichever tool text `_scene5_coping` actually assigned (Anchor,
/// Reframe, Savoring, grounding, ...) — split into steps by
/// [_splitStrategyIntoSteps] so the walkthrough always matches what Hati
/// said the strategy was, whatever it happened to be.
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
  // Every coping tool `_scene5_coping` (scenario_engine.py) hands back
  // arrives as one paragraph, not pre-split into steps. This used to show
  // that whole paragraph as a single "1/1" step with a lone "Finish
  // Practice" button — no real walkthrough at all. It also used to append
  // 3 more generic breathing/rehearsal steps regardless of which tool was
  // actually assigned, so e.g. "Pause and Label" or "Repair Message" would
  // show correct step-1 text and then silently switch to a grounding-style
  // script for steps 2-4 — that's gone too.
  //
  // _splitStrategyIntoSteps below paces the same approved sentences out
  // one at a time instead: no wording is added, removed, or reordered,
  // only sentence boundaries the psychologist-reviewed text already has.
  late final List<String> _steps = _splitStrategyIntoSteps(widget.strategy);

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

/// Steps down from bodyLarge's base 16 as the "What to remember" insight
/// gets longer — a single short sentence reads fine at full size, but a
/// multi-sentence insight the same size ran noticeably large inside its
/// fixed-width card. Same length-based approach scenario_shell.dart's own
/// _summaryFontSize already uses for the closing dialogue text.
double _insightFontSize(String text) {
  if (text.length > 260) return 13;
  if (text.length > 160) return 14;
  return 16;
}

class Scene6Closing extends StatefulWidget {
  const Scene6Closing({super.key});

  @override
  State<Scene6Closing> createState() => _Scene6ClosingState();
}

class _Scene6ClosingState extends State<Scene6Closing> {
  bool _dialogueComplete = false;

  // Once Hati's closing line has fully typed out, the bubble is no longer
  // needed on screen and was covering the "What to remember" card above it
  // — this fades it out instead (frog stays put), either automatically a
  // few seconds later or immediately if the player taps anywhere first.
  bool _bubbleHidden = false;
  Timer? _bubbleHideTimer;

  void _startBubbleHideTimer() {
    _bubbleHideTimer?.cancel();
    _bubbleHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_bubbleHidden) setState(() => _bubbleHidden = true);
    });
  }

  // Tapping anywhere already skips/advances Hati's typewriter mid-sentence
  // (see HatiTapToAdvance) — this only additionally dismisses the bubble
  // once there's nothing left to advance through.
  void _dismissBubbleOnTap() {
    if (_dialogueComplete && !_bubbleHidden) {
      setState(() => _bubbleHidden = true);
    }
  }

  @override
  void dispose() {
    _bubbleHideTimer?.cancel();
    super.dispose();
  }

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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissBubbleOnTap,
        child: HatiTapToAdvance(
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
                    color: const Color(0xFFF5F1E8).withValues(alpha: 0.08),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              children: [
                                const SceneProgressBar(
                                  currentStep: 6,
                                  totalSteps: 7,
                                  sceneLabel: 'Closing',
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: HatiColors.softGold.withValues(
                                      alpha: 0.2,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: HatiColors.softGold.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🏆',
                                      style: TextStyle(fontSize: 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HatiColors.softGold.withValues(
                                      alpha: 0.2,
                                    ),
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
                                    color: const Color(
                                      0xFFF5F1E8,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFF5F1E8,
                                      ).withValues(alpha: 0.12),
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
                                      const SizedBox(height: 8),
                                      Text(
                                        insight,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: const Color(
                                            0xFFF5F1E8,
                                          ).withValues(alpha: 0.85),
                                          fontSize: _insightFontSize(insight),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Hati + his closing bubble — an Expanded slot
                                // (not a fixed gap) so it claims whatever room
                                // is left between the "What to remember" card
                                // above and the Finish button below, on any
                                // screen size. HatiSpeakingBlock keeps the
                                // bubble attached right above Hati's head, and
                                // reverse:true pins that connected unit to the
                                // *bottom* of this slot, so leftover space
                                // always ends up between the card and Hati —
                                // never the other way around — which is what
                                // was letting the bubble cover the card before.
                                Expanded(
                                  child: SingleChildScrollView(
                                    reverse: true,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          child: _bubbleHidden
                                              ? const HatiFrogAvatar(
                                                  key: ValueKey('frog-only'),
                                                  size: 150,
                                                  mood: HatiMood.happy,
                                                )
                                              : HatiSpeakingBlock(
                                                  key: const ValueKey(
                                                    'speaking',
                                                  ),
                                                  persistentMessage:
                                                      closingLine,
                                                  frogSize: 150,
                                                  mood: HatiMood.happy,
                                                  onSequenceComplete: () {
                                                    if (mounted &&
                                                        !_dialogueComplete) {
                                                      setState(
                                                        () =>
                                                            _dialogueComplete =
                                                                true,
                                                      );
                                                      _startBubbleHideTimer();
                                                    }
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),
                                // Stays out of the tree — not just disabled —
                                // until the closing line has fully typed out,
                                // then pops in.
                                if (_dialogueComplete)
                                  PopIn(
                                    key: const ValueKey('finish-button'),
                                    child: HatiButton(
                                      label: finishLabel,
                                      icon: Icons.check_rounded,
                                      // Was the same 0xFF0B28D9 as this
                                      // screen's own background container
                                      // above — the button effectively had no
                                      // visible fill against it. The lighter
                                      // accent blue (same one Scene0's "Begin"
                                      // button uses) actually shows up.
                                      color: const Color(0xFF3DA9FC),
                                      onTap: provider.isLoading
                                          ? null
                                          : () => provider.submitText(
                                              finishLabel,
                                            ),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 52),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
