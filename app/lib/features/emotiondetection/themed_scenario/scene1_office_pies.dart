// ─────────────────────────────────────────────
// HATI – Scene 1: The Office & P.I.E.S. Check
// screens/scene1_office_pies.dart
//
// Adapted from testing_env/lib/scene1_office_pies.dart. Backend steps
// `pies_physical` / `pies_emotional` / `pies_environmental` all map to this
// scene (see scenario_models.kStepToScene). Chip options come straight from
// provider.ui.options each turn; the old local PIESData accumulation +
// hardcoded chip label->enum maps are gone — every chip tap submits the
// exact backend-provided option string immediately via submitText.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

class Scene1OfficePies extends StatefulWidget {
  const Scene1OfficePies({super.key});

  @override
  State<Scene1OfficePies> createState() => _Scene1OfficePiesState();
}

class _Scene1OfficePiesState extends State<Scene1OfficePies> {
  // Hati's P.I.E.S. prompt types out on the coach bubble; don't let the
  // player pick a chip until it's finished, or the tail end of the
  // question never gets shown before the step advances.
  String? _trackedStep;
  bool _dialogueComplete = false;

  int _stepIndex(String? step) {
    switch (step) {
      case 'pies_emotional':
        return 1;
      case 'pies_environmental':
        return 2;
      case 'pies_physical':
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final step = provider.backendStep;
    final index = _stepIndex(step);

    if (step != _trackedStep) {
      _trackedStep = step;
      _dialogueComplete = false;
    }

    const labels = ['Physical', 'Emotional', 'Environmental'];
    const emojis = ['🫀', '🧠', '👁️'];
    const subtitles = ['Physical · 1 of 3', 'Emotional · 2 of 3', 'Environmental · 3 of 3'];
    const selectedColors = [HatiColors.anxious, HatiColors.scared, HatiColors.calm];

    final hatiText = joinMessageText(provider.messages);

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Office'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Scene 1 / 7',
                style: HatiTextStyles.caption.copyWith(color: HatiColors.mintFresh),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: HatiColors.deepForest,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: const SceneProgressBar(
              currentStep: 1,
              totalSteps: 7,
              sceneLabel: 'The Office',
            ),
          ),
          Expanded(
            child: HatiSceneShell(
              showCoach: true,
              persistentMessage: hatiText,
              onSequenceComplete: () {
                if (mounted && !_dialogueComplete) {
                  setState(() => _dialogueComplete = true);
                }
              },
              body: provider.ui.type == ScenarioUIType.buttons
                  ? _PiesChipStep(
                      key: ValueKey(step),
                      label: labels[index],
                      emoji: emojis[index],
                      stepSubtitle: subtitles[index],
                      selectedColor: selectedColors[index],
                      options: provider.ui.options,
                      isLoading: provider.isLoading || !_dialogueComplete,
                      onSubmit: provider.submitText,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PiesChipStep extends StatefulWidget {
  final String label;
  final String emoji;
  final String stepSubtitle;
  final Color selectedColor;
  final List<String> options;
  final bool isLoading;
  final ValueChanged<String> onSubmit;

  const _PiesChipStep({
    super.key,
    required this.label,
    required this.emoji,
    required this.stepSubtitle,
    required this.selectedColor,
    required this.options,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<_PiesChipStep> createState() => _PiesChipStepState();
}

class _PiesChipStepState extends State<_PiesChipStep> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HatiColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: HatiColors.mossGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'P.I.E.S. CHECK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                widget.stepSubtitle,
                style: HatiTextStyles.caption.copyWith(color: HatiColors.textMedium),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PIESSection(
            label: widget.label,
            emoji: widget.emoji,
            options: widget.options,
            selected: _selected,
            selectedColor: widget.selectedColor,
            onSelect: widget.isLoading
                ? (_) {}
                : (opt) {
                    setState(() => _selected = opt);
                    widget.onSubmit(opt);
                  },
          ),
        ],
      ),
    );
  }
}
