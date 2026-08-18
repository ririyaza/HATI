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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

class Scene4Debrief extends StatelessWidget {
  const Scene4Debrief({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final step = provider.backendStep;
    final ui = provider.ui;
    final hatiText = joinMessageText(provider.messages);

    Widget body;
    if (step == 'scene4_predicted' || step == 'scene4_actual') {
      final question = step == 'scene4_predicted'
          ? 'How anxious did you expect to feel? (0–10)'
          : 'How anxious did you actually feel? (0–10)';
      body = _AnxietySliderCard(
        key: ValueKey(step),
        question: question,
        isLoading: provider.isLoading,
        onSubmit: (v) => provider.submitText(v.toString()),
      );
    } else if (ui.type == ScenarioUIType.buttons) {
      body = _DebriefChoiceCard(
        key: ValueKey(step),
        options: ui.options,
        isLoading: provider.isLoading,
        onSubmit: provider.submitText,
      );
    } else {
      body = TextResponseCard(
        key: ValueKey(step),
        hintText: ui.placeholder ?? 'Type your response...',
        isLoading: provider.isLoading,
        onSubmit: provider.submitText,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Debrief')),
      body: Column(
        children: [
          Container(
            color: HatiColors.deepForest,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: const SceneProgressBar(
              currentStep: 4,
              totalSteps: 7,
              sceneLabel: 'Post-Interaction Reflection',
            ),
          ),
          Expanded(
            child: HatiSceneShell(
              showCoach: true,
              persistentMessage: hatiText,
              frogWidthScale: 1.08,
              body: body,
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HatiColors.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SliderQuestion(
            question: widget.question,
            initial: _value,
            onChanged: (v) => _value = v,
          ),
          const SizedBox(height: 12),
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
    if (options.length == 1) {
      return HatiButton(
        label: options.first,
        icon: Icons.arrow_forward_rounded,
        onTap: isLoading ? null : () => onSubmit(options.first),
      );
    }
    return Column(
      children: [
        for (final opt in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HatiOutlineButton(
              label: opt,
              onTap: isLoading ? () {} : () => onSubmit(opt),
            ),
          ),
      ],
    );
  }
}
