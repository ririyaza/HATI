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

import 'package:firebase_auth/firebase_auth.dart';
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
  String? _selected;

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
    final config = provider.config;
    final step = provider.backendStep;
    final index = _stepIndex(step);

    if (step != _trackedStep) {
      _trackedStep = step;
      _dialogueComplete = false;
      _selected = null;
    }

    const labels = ['Physical', 'Emotional', 'Environmental'];
    const emojis = ['🫀', '🧠', '👁️'];
    const subtitles = [
      'Physical · 1 of 3',
      'Emotional · 2 of 3',
      'Environmental · 3 of 3',
    ];
    const selectedColors = [
      HatiColors.anxious,
      HatiColors.scared,
      HatiColors.calm,
    ];

    final hatiText = joinMessageText(provider.messages);
    final isPies = provider.ui.type == ScenarioUIType.buttons;

    // Some scenarios' opening setup names several NPCs in one paragraph
    // (fbop_spotlight's 5-professor panel, fne_stage's Carlo/Julia/Precious)
    // with nobody pictured — Scene 3 already reveals a multi-character line
    // one face at a time via SequentialNarratorReveal; this finds whichever
    // one of this step's messages is that introduction (the first one
    // naming 2+ of config.npcCharacters) and reuses the same reveal here.
    List<(String, String)> introBeats = const [];
    if (config.npcCharacters.length > 1) {
      for (final raw in provider.messages) {
        final text = parseSpeakerMessage(raw).text;
        final beats = splitNarratorBeats(text, config.npcCharacters);
        if (beats.length > 1) {
          introBeats = beats;
          break;
        }
      }
    }

    return Scaffold(
      body: ScenarioGradientBackground(
        backgroundAsset: config.backgroundAsset,
        child: Column(
          children: [
            const SceneTopHeader(
              currentStep: 1,
              totalSteps: 7,
              sceneLabel: 'The Office',
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
                // fixedHeader and body end up as direct siblings inside
                // DraggableChoiceSheet's own Column, so their PopIn keys
                // must differ — a 'header:'/'body:' prefix keeps that true
                // even though today's nesting happens to avoid a collision.
                fixedHeader: isPies
                    ? popInIfReady(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (introBeats.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  0,
                                ),
                                child: SequentialNarratorReveal(
                                  beats: introBeats,
                                  avatarSize: 110,
                                ),
                              ),
                            _PiesHeader(
                              label: labels[index],
                              emoji: emojis[index],
                              stepSubtitle: subtitles[index],
                            ),
                          ],
                        ),
                        ready: _dialogueComplete,
                        stepKey: 'header:${step ?? index}',
                      )
                    : null,
                // Chips/text field stay out of the tree entirely (not just
                // disabled) until Hati's prompt has fully typed out, then
                // pop in via PopIn — previously they rendered immediately
                // just grayed out, so the tail end of a long prompt could
                // still be typing while the options already sat there.
                body: isPies && _dialogueComplete
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: PopIn(
                          key: ValueKey('body:$step'),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: provider.ui.options
                                .map(
                                  (opt) => PIESChip(
                                    label: opt,
                                    selected: _selected == opt,
                                    selectedColor: selectedColors[index],
                                    enabled: !provider.isLoading,
                                    onTap: provider.isLoading
                                        ? () {}
                                        : () {
                                            setState(() => _selected = opt);
                                            provider.submitText(opt);
                                          },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      )
                    : null,
                // "Other" tapped on any P.I.E.S. category switches the
                // backend to a text_input turn ("Tell me more:"). Pinned as
                // a fixed bottomBar — the same slot every other primary
                // action in this scene shell uses — rather than the
                // scrollable body, so the field + Send button are always
                // fully visible without needing to scroll past the coach
                // zone to reach them. Hidden (not just disabled) until
                // Hati's line finishes typing, same as the chips above.
                bottomBar: isPies || !_dialogueComplete
                    ? null
                    : PopIn(
                        key: ValueKey(step),
                        child: TextResponseCard(
                          key: ValueKey(step),
                          hintText: provider.ui.placeholder ?? 'Tell me more...',
                          isLoading: provider.isLoading,
                          onSubmit: provider.submitText,
                          onSubmitAudio: (path) => provider.submitAudio(
                            path,
                            userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          ),
                        ),
                      ),
                // Only paints the white content panel once the chips are
                // actually showing — otherwise it left a blank white box
                // sitting there for the whole time Hati was still typing.
                contentBackgroundColor: isPies && _dialogueComplete
                    ? Colors.white
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fixed header — the "P.I.E.S. CHECK" badge/subtitle plus the current
// section's emoji+label (e.g. "🫀 Physical"). Sits above the scrollable
// chip list so scrolling a long option list never carries this away with
// it.
class _PiesHeader extends StatelessWidget {
  final String label;
  final String emoji;
  final String stepSubtitle;

  const _PiesHeader({
    required this.label,
    required this.emoji,
    required this.stepSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
                stepSubtitle,
                style: HatiTextStyles.caption.copyWith(
                  color: HatiColors.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(label, style: HatiTextStyles.heading3),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
