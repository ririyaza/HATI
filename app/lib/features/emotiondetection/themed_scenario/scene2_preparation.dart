// ─────────────────────────────────────────────
// HATI – Scene 2: Preparation & Intention
// screens/scene2_preparation.dart
//
// Adapted from testing_env/lib/scene2_preparation.dart. Backend steps
// `foa_s2_script` / `foa_s2_script_custom` / `foa_s2_q_prep` /
// `foa_s2_ready` all map to this scene. Script cards and the final
// "Approach" CTA are built entirely from provider.ui.options — including
// the custom-script path, which is just the literal last option
// ("I'll type my own line") the backend already sends; tapping it submits
// that same string and the backend itself routes to foa_s2_script_custom.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

class Scene2Preparation extends StatefulWidget {
  const Scene2Preparation({super.key});

  @override
  State<Scene2Preparation> createState() => _Scene2PreparationState();
}

class _Scene2PreparationState extends State<Scene2Preparation> {
  // See Scene0PreSetup/Scene1OfficePies: don't let the player act on a
  // button/script choice until Hati's coach text has finished typing.
  String? _trackedStep;
  bool _dialogueComplete = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final step = provider.backendStep;
    final ui = provider.ui;
    final hatiText = joinMessageText(provider.messages);

    if (step != _trackedStep) {
      _trackedStep = step;
      _dialogueComplete = false;
    }

    Widget? body;
    Widget? bottomBar;

    if (ui.type == ScenarioUIType.buttons) {
      if (ui.options.length == 1) {
        // e.g. foa_s2_ready -> ["Approach"]
        bottomBar = HatiButton(
          label: ui.options.first,
          icon: Icons.directions_walk_rounded,
          color: HatiColors.leafGreen,
          onTap: (provider.isLoading || !_dialogueComplete)
              ? null
              : () => provider.submitText(ui.options.first),
        );
      } else {
        // foa_s2_script -> canned scripts + "write your own" option.
        body = _ScriptChoiceList(
          key: ValueKey(step),
          options: ui.options,
          isLoading: provider.isLoading || !_dialogueComplete,
          onSubmit: provider.submitText,
        );
      }
    } else {
      // foa_s2_script_custom / foa_s2_q_prep: free text.
      body = TextResponseCard(
        key: ValueKey(step),
        hintText: ui.placeholder ?? 'Type your response...',
        isLoading: provider.isLoading,
        onSubmit: provider.submitText,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Preparation')),
      body: Column(
        children: [
          Container(
            color: HatiColors.deepForest,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: const SceneProgressBar(
              currentStep: 2,
              totalSteps: 7,
              sceneLabel: 'Preparation & Intention',
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
              body: body,
              bottomBar: bottomBar,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScriptChoiceList extends StatelessWidget {
  final List<String> options;
  final bool isLoading;
  final ValueChanged<String> onSubmit;

  const _ScriptChoiceList({
    super.key,
    required this.options,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Choose Your Script',
          subtitle: 'Select one or write your own',
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < options.length; i++)
          ScriptOptionCard(
            label: String.fromCharCode(65 + i), // A, B, C, ...
            script: options[i],
            selected: false,
            onTap: isLoading ? () {} : () => onSubmit(options[i]),
          ),
      ],
    );
  }
}
