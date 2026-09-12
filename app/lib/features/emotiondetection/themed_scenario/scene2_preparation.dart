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
//
// `scene2_difficulty` also maps here (see scenario_models.kStepToScene) —
// it's the shared Easy/Difficult mode selector every theme shows right
// before Scene 3 begins. It's special-cased by step name below so its two
// options ("Easy Mode" / "Difficult Mode") render as a plain choice list
// instead of being swept into the generic multi-option branch, which is
// built for lettered script/opening-line picks and would otherwise label
// this step "Choose Your Script".
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
    Widget? fixedHeader;
    Color? contentBackgroundColor;

    if (ui.type == ScenarioUIType.buttons) {
      if (ui.options.length == 1) {
        // e.g. foa_s2_ready -> ["Approach"]
        bottomBar = HatiButton(
          label: ui.options.first,
          icon: Icons.directions_walk_rounded,
          color: HatiColors.leafGreen,
          onTap: provider.isLoading
              ? null
              : () => provider.submitText(ui.options.first),
        );
      } else if (step == 'scene2_difficulty') {
        // Easy Mode / Difficult Mode — a plain choice list (reusing the
        // same SectionHeader + HatiOutlineButton pattern Scene4Debrief uses
        // for its own non-script multi-option steps), not the lettered
        // script cards below.
        contentBackgroundColor = Colors.white;
        fixedHeader = const SectionHeader(
          title: 'Choose Your Difficulty',
          subtitle: 'Both are valid ways to practice',
        );
        final isLoading = provider.isLoading;
        body = Column(
          key: ValueKey(step),
          children: [
            for (final opt in ui.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HatiOutlineButton(
                  label: opt,
                  enabled: !isLoading,
                  onTap: isLoading ? () {} : () => provider.submitText(opt),
                ),
              ),
          ],
        );
      } else {
        // foa_s2_script -> canned scripts + "write your own" option. Solid
        // white behind the whole section (not just a card) so none of the
        // green background shows through on the sides or below a short
        // list of options.
        contentBackgroundColor = Colors.white;
        fixedHeader = const SectionHeader(
          title: 'Choose Your Script',
          subtitle: 'Select one or write your own',
        );
        body = _ScriptChoiceList(
          key: ValueKey(step),
          options: ui.options,
          isLoading: provider.isLoading,
          onSubmit: provider.submitText,
        );
      }
    } else {
      // foa_s2_script_custom / foa_s2_q_prep: free text. Lives in bottomBar
      // (fixed, always on-screen) rather than the scrollable body — same
      // slot every other primary action (Continue button, choice list) uses,
      // so the text field + Send button can never get pushed below the fold
      // by the coach zone above it.
      bottomBar = TextResponseCard(
        key: ValueKey(step),
        hintText: ui.placeholder ?? 'Type your response...',
        isLoading: provider.isLoading,
        onSubmit: provider.submitText,
      );
    }

    // Header/choices/input stay out of the tree — not just disabled — until
    // Hati's coach line for this step has fully typed out, then pop in
    // together (see popInIfReady/PopIn in shared_widgets.dart). fixedHeader
    // and body end up as direct siblings inside DraggableChoiceSheet's own
    // Column, so their PopIn keys must differ — reusing the same stepKey
    // for both previously triggered a "Duplicate keys found" crash.
    body = popInIfReady(
      body,
      ready: _dialogueComplete,
      stepKey: 'body:${step ?? ''}',
    );
    bottomBar = popInIfReady(
      bottomBar,
      ready: _dialogueComplete,
      stepKey: 'bottomBar:${step ?? ''}',
    );
    fixedHeader = popInIfReady(
      fixedHeader,
      ready: _dialogueComplete,
      stepKey: 'header:${step ?? ''}',
    );
    // Otherwise this left a blank white box sitting there for the whole
    // time Hati was still typing, even with body/fixedHeader hidden above.
    if (!_dialogueComplete) contentBackgroundColor = null;

    return Scaffold(
      body: ScenarioGradientBackground(
        backgroundAsset: config.backgroundAsset,
        child: Column(
          children: [
            const SceneTopHeader(
              currentStep: 2,
              totalSteps: 7,
              sceneLabel: 'Preparation & Intention',
            ),
            const SceneSpeedToggleRow(),
            Expanded(
              child: HatiSceneShell(
                showCoach: true,
                persistentMessage: hatiText,
                mood: HatiMood.thinking,
                onSequenceComplete: () {
                  if (mounted && !_dialogueComplete) {
                    setState(() => _dialogueComplete = true);
                  }
                },
                fixedHeader: fixedHeader,
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

class _ScriptChoiceList extends StatefulWidget {
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
  State<_ScriptChoiceList> createState() => _ScriptChoiceListState();
}

class _ScriptChoiceListState extends State<_ScriptChoiceList> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.options.length; i++)
          ScriptOptionCard(
            label: String.fromCharCode(65 + i), // A, B, C, ...
            script: widget.options[i],
            selected: _selectedIndex == i,
            enabled: !widget.isLoading,
            onTap: widget.isLoading
                ? () {}
                : () {
                    setState(() => _selectedIndex = i);
                    widget.onSubmit(widget.options[i]);
                  },
          ),
      ],
    );
  }
}
