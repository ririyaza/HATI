// ─────────────────────────────────────────────
// HATI – Scene 4: Post-Interaction Debrief
// screens/scene4_debrief.dart
//
// Adapted from testing_env/lib/scene4_debrief.dart. Backend steps
// `scene4_debrief_intro` / `scene4_predicted` / `scene4_actual` /
// `scene4_bad` / `scene4_bad_detail` / `scene4_credit` /
// `scene4_personalized` all map to this scene. `scene4_predicted` and
// `scene4_actual` arrive as `buttons` with options ["0".."10"] — rendered
// here as a slider (matching the prototype's UX) but submitted as the
// chosen integer's string via submitText, exactly like every other turn.
// ─────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

class Scene4Debrief extends StatefulWidget {
  const Scene4Debrief({super.key});

  @override
  State<Scene4Debrief> createState() => _Scene4DebriefState();
}

class _Scene4DebriefState extends State<Scene4Debrief> {
  String? _trackedStep;
  bool _dialogueComplete = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final config = provider.config;
    final step = provider.backendStep;
    final ui = provider.ui;
    final hatiText = joinMessageText(provider.messages);

    if (step != _trackedStep) {
      _trackedStep = step;
      _dialogueComplete = false;
    }

    Widget? body;
    Widget? bottomBar;
    Color? contentBackgroundColor;
    if (step == 'scene4_predicted' ||
        step == 'scene4_actual' ||
        step == 'scene4_fne_severity') {
      final String question;
      switch (step) {
        case 'scene4_predicted':
          question = 'How anxious did you expect to feel? (0–10)';
          break;
        case 'scene4_actual':
          question = 'How anxious did you actually feel? (0–10)';
          break;
        default:
          question = 'How bad was the actual outcome? (0–10)';
      }
      contentBackgroundColor = Colors.white;
      body = _AnxietySliderCard(
        key: ValueKey(step),
        question: question,
        isLoading: provider.isLoading,
        onSubmit: (v) => provider.submitText(v.toString()),
      );
    } else if (ui.type == ScenarioUIType.buttons) {
      if (ui.options.length == 1) {
        // Single "Continue"-style option — pin it as a fixed bottom bar
        // on the plain green background, same as Preparation &
        // Intention's single-option case, with no white content panel
        // (there's no body content, so a white panel would just be an
        // empty gap above the button).
        bottomBar = HatiButton(
          label: ui.options.first,
          icon: Icons.arrow_forward_rounded,
          onTap: provider.isLoading
              ? null
              : () => provider.submitText(ui.options.first),
        );
      } else if (looksLikeNumericScale(ui.options)) {
        // Any other numeric rating turn the backend sends (a mid-flow
        // SUDS-style check not covered by the three named steps above) —
        // same slider treatment instead of falling through to a wall of
        // individual number buttons.
        contentBackgroundColor = Colors.white;
        body = ScaleChoiceCard(
          key: ValueKey(step),
          options: ui.options,
          isLoading: provider.isLoading,
          onSubmit: provider.submitText,
        );
      } else {
        contentBackgroundColor = Colors.white;
        body = _DebriefChoiceCard(
          key: ValueKey(step),
          options: ui.options,
          isLoading: provider.isLoading,
          onSubmit: provider.submitText,
        );
      }
    } else {
      // Free text — pinned as a fixed bottom bar (like the single-Continue
      // case above) rather than the scrollable body, so the text field +
      // Send button can never get pushed below the fold by the coach zone.
      bottomBar = TextResponseCard(
        key: ValueKey(step),
        hintText: ui.placeholder ?? 'Type your response...',
        isLoading: provider.isLoading,
        onSubmit: provider.submitText,
        onSubmitAudio: (path) => provider.submitAudio(
          path,
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
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
    // Otherwise this left a blank white box sitting there for the whole
    // time Hati was still typing, even with body hidden above.
    if (!_dialogueComplete) contentBackgroundColor = null;

    return Scaffold(
      body: ScenarioGradientBackground(
        backgroundAsset: config.backgroundAsset,
        child: Column(
          children: [
            const SceneTopHeader(
              currentStep: 4,
              totalSteps: 7,
              sceneLabel: 'Post-Interaction Reflection',
            ),
            const SceneSpeedToggleRow(),
            Expanded(
              child: HatiSceneShell(
                showCoach: true,
                persistentMessage: hatiText,
                mood: HatiMood.encourage,
                onSequenceComplete: () {
                  if (mounted && !_dialogueComplete) {
                    setState(() => _dialogueComplete = true);
                  }
                },
                body: body,
                bottomBar: bottomBar,
                contentBackgroundColor: contentBackgroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnxietySliderCard extends StatefulWidget {
  final String question;
  final bool isLoading;
  final ValueChanged<int> onSubmit;

  const _AnxietySliderCard({
    super.key,
    required this.question,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<_AnxietySliderCard> createState() => _AnxietySliderCardState();
}

class _AnxietySliderCardState extends State<_AnxietySliderCard> {
  int _value = 5;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SliderQuestion(
            question: widget.question,
            initial: _value,
            onChanged: (v) => _value = v,
          ),
          const SizedBox(height: 10),
          HatiButton(
            label: 'Next',
            icon: Icons.arrow_forward_rounded,
            onTap: widget.isLoading ? null : () => widget.onSubmit(_value),
          ),
        ],
      ),
    );
  }
}

class _DebriefChoiceCard extends StatelessWidget {
  final List<String> options;
  final bool isLoading;
  final ValueChanged<String> onSubmit;

  const _DebriefChoiceCard({
    super.key,
    required this.options,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final opt in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HatiOutlineButton(
              label: opt,
              enabled: !isLoading,
              onTap: isLoading ? () {} : () => onSubmit(opt),
            ),
          ),
      ],
    );
  }
}
