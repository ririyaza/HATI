// ─────────────────────────────────────────────
// HATI – Scene 3: The Approach & NPC Interaction
// screens/scene3_interaction.dart
//
// Adapted from testing_env/lib/scene3_interaction.dart. Every scenario's
// preparation/interaction steps (see scenario_models.kStepToScene) map to
// this scene. The old hardcoded ResponseBranch-keyed reaction switch
// (confident/anxious/angry/freeze dialogue) is dropped entirely — NPC
// dialogue and Hati's coaching text are read directly from
// provider.messages every turn, parsed by speaker prefix (e.g.
// "**Professor:**" / "**Narrator:**" / "**Hati:**").
//
// Background art and (optional) character sprite come from
// provider.config, generalized per scenario: `foa_supervisor` keeps its
// bespoke classroom + professor sprite art; every other scenario renders
// full-bleed background art only (config.spriteAsset == null), with the
// sprite portion of the layout skipped gracefully.
//
// This scene also owns its own AudioRecorder (record package, WAV/16kHz/
// mono), mirroring scenario_game.dart's pattern but not sharing code with
// it. Voice input is only offered while the backend expects free text
// (ui.type == text_input) — the two turns are the opening line to the NPC
// and the follow-up reply.
// ─────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:rive/rive.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

const _kApproachBlue = Color(0xFF4A8FD4);
const _kApproachCyan = Color(0xFF00D4FF);
const _kFrogSize = 120.0;

class Scene3Interaction extends StatefulWidget {
  const Scene3Interaction({super.key});

  @override
  State<Scene3Interaction> createState() => _Scene3InteractionState();
}

class _Scene3InteractionState extends State<Scene3Interaction> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _record = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _lastSentText;

  // Hati's coach line types out over the scene; don't let "Continue"
  // advance past it before the last of it has actually been shown.
  String? _trackedBubbleKey;
  bool _dialogueComplete = false;

  // True once the player taps "Write your own response" on a multi-choice
  // turn — swaps the DraggableChoiceSheet for the same textbox+voice input
  // bar the free-text turns use, instead of only ever offering the backend's
  // pre-written options. Reset alongside _dialogueComplete on every new turn
  // (see the bubbleKey check below) so the next choice screen defaults back
  // to showing the option cards.
  bool _useCustomResponse = false;

  Future<void> _startRecording() async {
    if (await _record.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/themed_scenario_record.wav';

      await _record.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: path,
      );

      if (mounted) setState(() => _isRecording = true);
    } else if (mounted) {
      // hasPermission() returned false with no further feedback — tapping
      // the mic used to just do nothing here, with no way for the player
      // to know why voice input wasn't working. They can still type their
      // response instead, so this isn't a dead end, just needs to say so.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Microphone access is off, so voice input isn't available "
            "right now — you can still type your response below. To use "
            "voice, allow microphone access for HATI in your device's "
            "Settings.",
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _stopRecording(ScenarioProvider provider) async {
    final path = await _record.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path == null) return;

    setState(() => _isTranscribing = true);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await provider.submitAudio(path, userId: userId);
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
    if (!mounted) return;
    setState(() {
      _lastSentText = provider.lastTranscript?.trim().isNotEmpty == true
          ? provider.lastTranscript
          : '[Voice message sent]';
    });
  }

  void _sendText(ScenarioProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _lastSentText = text);
    provider.submitText(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final step = provider.backendStep;
    final config = provider.config;
    final sceneHeight = MediaQuery.sizeOf(context).height;
    // Mood-specific art (e.g. the professor's annoyed animation) only
    // swaps in while the backend's latest npc_mood matches — otherwise
    // falls back to the scenario's default sprite.
    final activeSpriteAsset =
        (provider.npcMood == 'angry' && config.spriteAssetAngry != null)
        ? config.spriteAssetAngry
        : config.spriteAsset;

    final parsed = provider.messages.map(parseSpeakerMessage).toList();
    // isHatiSpeaker does a startsWith match (not equality) so variants like
    // "Hati (sidebar)" — seen in fbop_spotlight's Easy-mode script — still
    // land in Hati's own lane instead of being mistaken for an NPC line.
    final hatiLines = parsed
        .where((p) => isHatiSpeaker(p.speaker))
        .map((p) => p.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    final npcParsed = parsed.where((p) => !isHatiSpeaker(p.speaker)).toList();

    // config.npcCharacters is only populated for the 5 multi/single-NPC
    // scenarios (fbop_spotlight, fne_stage, fsg_party, fsn_seat,
    // phys_jeepney) — see scenario_models.dart. Every other scenario
    // (foa_supervisor, foa_classroom) keeps the original single-bubble +
    // single-big-sprite rendering further below, untouched.
    final useMultiSpeakerLayout = config.npcCharacters.isNotEmpty;
    final speakerBlocks = useMultiSpeakerLayout
        ? _buildSpeakerBlocks(config, npcParsed, provider.npcMood == 'angry')
        : const <_SpeakerBlock>[];
    // A single-NPC scenario (fsn_seat's Stranger, phys_jeepney's Classmate)
    // otherwise vanishes entirely on any turn where she's only mentioned in
    // narration ("The stranger continues typing and does not respond.")
    // rather than actually speaking, since sprites are only attached to
    // this turn's speaker blocks. Fall back to her idle sprite so she stays
    // visibly present even on a silent turn.
    final singleNpcCharacter = config.npcCharacters.length == 1
        ? config.npcCharacters.first
        : null;
    final needsSingleNpcFallback =
        singleNpcCharacter != null &&
        !speakerBlocks.any((b) => b.spriteAsset != null);
    final profText = useMultiSpeakerLayout
        ? ''
        : npcParsed
              .map((p) => p.text)
              .where((t) => t.trim().isNotEmpty)
              .join('\n\n');
    // fsg_party/fsn_seat/phys_jeepney's NPC avatar matches foa_supervisor's
    // single-sprite sizing by request — fbop_spotlight and fne_stage keep
    // the smaller fixed _SpeakerBlockWidget default (130) they already had,
    // since those weren't part of the ask. At the larger size, the bubble
    // also needs foa's own stacked (bubble-above-sprite) layout instead of
    // the default side-by-side Row — see _SpeakerBlockWidget.stackVertically.
    // (0.34 of the full screen height used to be fine when this sprite was
    // the only thing sharing the scene's vertical space; now that the NPC
    // dialogue, the player's echoed line, and Hati all have to fit without
    // scrolling, 0.34 left too little room and the three collided — see
    // the "this part was messed up" fix.)
    const matchFoaSizeKeys = {'fsg_party', 'fsn_seat', 'phys_jeepney'};
    final matchesFoaLayout = matchFoaSizeKeys.contains(config.scenarioKey);
    final npcAvatarSize = matchesFoaLayout
        ? sceneHeight * 0.22
        : _SpeakerBlockWidget.defaultAvatarSize;
    // fsn_seat/phys_jeepney only ever have ONE character. A Narrator line
    // in the middle of her turn ("The stranger moves their bag.") splits
    // her dialogue into two _SpeakerBlocks either side of it (see
    // _buildSpeakerBlocks) — each block used to render its own full-size
    // portrait, so a single turn could stack her picture on screen twice
    // for no reason. Only the last block gets a sprite for these
    // single-character scenarios; fbop_spotlight/fne_stage (real
    // multi-character panels) still show every distinct speaker's sprite.
    final isSingleNpcScenario = config.npcCharacters.length == 1;
    final hatiText = hatiLines.join('\n\n');
    final isTextInput = provider.ui.type == ScenarioUIType.textInput;

    final bubbleKey = '$step:$hatiText';
    if (bubbleKey != _trackedBubbleKey) {
      _trackedBubbleKey = bubbleKey;
      _dialogueComplete = false;
      _useCustomResponse = false;
    }
    // No Hati line to wait for on this turn -> nothing blocks "Continue".
    final dialogueReady = hatiText.isEmpty || _dialogueComplete;

    return Scaffold(
      backgroundColor: _kApproachBlue,
      body: HatiTapToAdvance(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 3 of 7 — the same shared scene numbering every other scene's
              // SceneTopHeader uses (1=Office, 2=Preparation, 4=Debrief,
              // 5=Coping, 6=Closing). Previously this varied by step name
              // within Interaction itself (0.15/0.55/0.9), fractions that
              // didn't correspond to anything real.
              const _ApproachTopBar(currentStep: 3, totalSteps: 7),
              const SceneSpeedToggleRow(),
              Expanded(
                // LayoutBuilder just to learn how tall this area actually
                // is, so Layer 2 below can be capped to a sane fraction of
                // it — a safety net, not the primary fix (see
                // isSingleNpcScenario/showSprite above for that): without
                // any cap, a turn with an unusually long NPC/narrator
                // exchange could still grow tall enough to crash into the
                // player's echoed line and Hati beneath it.
                child: LayoutBuilder(
                  builder: (context, stackConstraints) {
                    final npcContentMaxHeight =
                        stackConstraints.maxHeight * 0.6;
                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      // Explicit paint/priority order, back to front: (1)
                      // the scenario's own background art, (2) the NPC's
                      // dialogue this turn, (3) the player's own echoed
                      // last message, (4) Hati himself. Each is its own
                      // Positioned layer instead of one flex column, so
                      // none of them are ever scrolled to be read — every
                      // layer sizes to its own content and simply overlaps
                      // a layer behind it on the rare turn where there
                      // isn't room for both, which is fine given the paint
                      // order above (whatever's in front stays legible).
                      children: [
                        // Layer 1 (back): background art.
                        Image.asset(
                          config.backgroundAsset,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        // Layer 2: the NPC's dialogue this turn — one
                        // bubble + sprite (or every speaker's block, for
                        // the 5 multi/single-NPC scenarios), pinned to the
                        // top of the scene. Clipped (not scrolled) to
                        // npcContentMaxHeight as a last-resort safety net —
                        // OverflowBox lets the Column lay out at its real
                        // (possibly taller) size instead of throwing a
                        // RenderFlex overflow, and the ClipRect around it
                        // is what actually crops the excess.
                        Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: SizedBox(
                            height: npcContentMaxHeight,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                maxHeight: double.infinity,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: useMultiSpeakerLayout
                                      ? [
                                          // One visually distinct block per
                                          // speaker run this turn: name
                                          // label + bubble, plus that
                                          // character's small mood sprite
                                          // (see _SpeakerBlockWidget below)
                                          // — so in e.g. the 5-professor
                                          // panel it's always clear who
                                          // said which line.
                                          for (
                                            var i = 0;
                                            i < speakerBlocks.length;
                                            i++
                                          ) ...[
                                            _SpeakerBlockWidget(
                                              block: speakerBlocks[i],
                                              avatarSize: npcAvatarSize,
                                              stackVertically: matchesFoaLayout,
                                              // Single-character scenarios
                                              // (fsn_seat, phys_jeepney)
                                              // only show her portrait on
                                              // the LAST block this turn —
                                              // see showSprite's doc.
                                              showSprite:
                                                  !isSingleNpcScenario ||
                                                  i == speakerBlocks.length - 1,
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                          if (needsSingleNpcFallback)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child:
                                                  singleNpcCharacter
                                                      .sprites
                                                      .blink
                                                      .endsWith('.riv')
                                                  ? NpcRiveSprite(
                                                      assetPath:
                                                          singleNpcCharacter
                                                              .sprites
                                                              .blink,
                                                      height: npcAvatarSize,
                                                    )
                                                  : Image.asset(
                                                      singleNpcCharacter
                                                          .sprites
                                                          .blink,
                                                      height: npcAvatarSize,
                                                      fit: BoxFit.contain,
                                                    ),
                                            ),
                                        ]
                                      : [
                                          if (profText.isNotEmpty)
                                            _CharacterSpeechBubble(
                                              text: profText,
                                            ),
                                          if (activeSpriteAsset != null) ...[
                                            const SizedBox(height: 8),
                                            // NPC art is either a static
                                            // image or a Rive animation
                                            // (.riv) — Image.asset can't
                                            // decode Rive's binary format,
                                            // so branch by extension. Keyed
                                            // by asset path so switching
                                            // between the default and angry
                                            // sprite (different widget
                                            // subtrees/state) rebuilds
                                            // cleanly.
                                            activeSpriteAsset.endsWith('.riv')
                                                ? NpcRiveSprite(
                                                    key: ValueKey(
                                                      activeSpriteAsset,
                                                    ),
                                                    assetPath:
                                                        activeSpriteAsset,
                                                    height: sceneHeight * 0.34,
                                                  )
                                                : Image.asset(
                                                    activeSpriteAsset,
                                                    height: sceneHeight * 0.34,
                                                    fit: BoxFit.contain,
                                                  ),
                                          ],
                                        ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Layer 3: the player's own echoed last message — its
                        // own layer above the NPC's, pinned to the opposite
                        // (bottom-right) corner from Hati below so the two
                        // never compete for the same spot.
                        if (_lastSentText != null && _lastSentText!.isNotEmpty)
                          Positioned(
                            left: 96,
                            right: 16,
                            bottom: 16,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _CharacterSpeechBubble(
                                text: _lastSentText!,
                              ),
                            ),
                          ),
                        // Layer 4 (front): Hati. Position and size are fixed —
                        // he never scales down or shifts to make room for
                        // anything else on screen. Only his speech bubble
                        // (rendered above him, see _ApproachHatiLane) grows or
                        // shrinks with whatever he's saying, and it's free to
                        // overlap the art/NPC/echo layers behind it since it's
                        // the frontmost thing in the scene and fades away on
                        // its own a few seconds after it finishes typing
                        // anyway (dissolveBubble/autoAdvance below).
                        Positioned(
                          left: 8,
                          bottom: 4,
                          child: _ApproachHatiLane(
                            showBubble: hatiText.isNotEmpty,
                            message: hatiText,
                            bubbleKey: bubbleKey,
                            frogSize: _kFrogSize,
                            onSequenceComplete: () {
                              if (mounted && !_dialogueComplete) {
                                setState(() => _dialogueComplete = true);
                              }
                            },
                          ),
                        ),
                        // Difficult Mode's branch points (e.g. "Sorry, I just
                        // wanted to..." / "Never mind." / continue angrily /
                        // custom) send several real choices, not one default
                        // "Continue" — show every option instead of silently
                        // only offering the first. A draggable sheet overlaying
                        // the dialogue above (matching HatiSceneShell's own
                        // header+choices sheet everywhere else) rather than a
                        // fixed-size panel, so the header and the option cards
                        // drag up together as one unit.
                        if (dialogueReady &&
                            !isTextInput &&
                            !_useCustomResponse &&
                            provider.ui.options.length > 1)
                          PopIn(
                            key: ValueKey(bubbleKey),
                            child: DraggableChoiceSheet(
                              header: const SectionHeader(
                                title: 'Choose Your Response',
                                subtitle: 'Select one or write your own',
                              ),
                              body: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var i = 0;
                                    i < provider.ui.options.length;
                                    i++
                                  )
                                    ScriptOptionCard(
                                      label: String.fromCharCode(65 + i),
                                      script: provider.ui.options[i],
                                      selected: false,
                                      enabled: !provider.isLoading,
                                      onTap: provider.isLoading
                                          ? () {}
                                          : () => provider.submitText(
                                              provider.ui.options[i],
                                            ),
                                    ),
                                  // The sheet's own subtitle above promises
                                  // "write your own" — this is that option:
                                  // switches to the same textbox+voice bar the
                                  // free-text turns use instead of submitting
                                  // one of the pre-written options.
                                  _CustomResponseCard(
                                    enabled: !provider.isLoading,
                                    onTap: () => setState(
                                      () => _useCustomResponse = true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              // The input bar / single continue button stay out of the tree
              // — not just disabled — until Hati's and the NPC's lines this
              // turn have fully typed out, then pop in via PopIn. The
              // multi-option case above is handled by the draggable sheet
              // overlay instead, not this fixed-height bottom slot.
              if (!dialogueReady)
                const SizedBox.shrink()
              else if (isTextInput || _useCustomResponse)
                PopIn(
                  key: ValueKey('$bubbleKey:input'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Only reachable via "Write your own response" on a
                      // turn that actually had preset choices — a real
                      // isTextInput turn has no choice sheet to go back to.
                      if (_useCustomResponse && !isTextInput)
                        Container(
                          color: Colors.white,
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _useCustomResponse = false),
                              style: TextButton.styleFrom(
                                foregroundColor: _kApproachBlue,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                              ),
                              label: const Text('Back to choices'),
                            ),
                          ),
                        ),
                      _ApproachInputBar(
                        controller: _controller,
                        enabled:
                            !provider.isLoading &&
                            !_isRecording &&
                            !_isTranscribing,
                        isRecording: _isRecording,
                        isTranscribing: _isTranscribing,
                        hintText: _isRecording
                            ? 'Listening…'
                            : (_isTranscribing
                                  ? 'Converting your voice…'
                                  : 'Type your response...'),
                        onSend: () => _sendText(provider),
                        onMicTap: () => _isRecording
                            ? _stopRecording(provider)
                            : _startRecording(),
                      ),
                    ],
                  ),
                )
              else if (provider.ui.options.length <= 1)
                PopIn(
                  key: ValueKey(bubbleKey),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: SafeArea(
                      top: false,
                      child: HatiButton(
                        label: provider.ui.options.isNotEmpty
                            ? provider.ui.options.first
                            : 'Continue',
                        icon: Icons.arrow_forward_rounded,
                        onTap: provider.isLoading
                            ? null
                            : () => provider.submitText(
                                provider.ui.options.isNotEmpty
                                    ? provider.ui.options.first
                                    : 'Continue',
                              ),
                      ),
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

// ── Hati overlay: frog + bubble, front-most layer of the scene ─────────────
/// The caller wraps this in a plain `Positioned(left, bottom)` with a fixed
/// [frogSize] — this widget itself no longer does any of its own alignment
/// or scaling, so Hati's position and size stay exactly the same regardless
/// of what else is on screen. Only the bubble above him grows or shrinks
/// with the message, sized by [HatiLayout.bubbleMaxWidth]/[bubbleMaxHeight]
/// — it's free to extend past the art/NPC layers behind it since this is
/// the front-most layer in the scene's Stack.
class _ApproachHatiLane extends StatelessWidget {
  final bool showBubble;
  final String message;
  final String bubbleKey;
  final double frogSize;
  final VoidCallback? onSequenceComplete;

  const _ApproachHatiLane({
    required this.showBubble,
    required this.message,
    required this.bubbleKey,
    this.frogSize = 100,
    this.onSequenceComplete,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: HatiLayout.bubbleMaxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBubble && message.isNotEmpty)
            HatiSpeakingBlock(
              key: ValueKey(bubbleKey),
              persistentMessage: message,
              frogSize: frogSize,
              mood: HatiMood.encourage,
              // Fades the bubble out on its own a few seconds after it
              // finishes typing, leaving just the frog — it used to stay
              // put indefinitely until the player tapped. autoAdvance adds
              // this timeout as a fallback only — tapping still dismisses
              // it (or fast-forwards it while typing) immediately, same as
              // before.
              dissolveBubble: true,
              autoAdvance: true,
              holdAfterTyping: const Duration(seconds: 3),
              onSequenceComplete: onSequenceComplete,
            )
          else
            HatiFrogAvatar(size: frogSize, mood: HatiMood.encourage),
        ],
      ),
    );
  }
}

// ── Top bar (reference-style) ─────────────────────────────────────────────────

class _ApproachTopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _ApproachTopBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;

    return Container(
      color: _kApproachBlue,
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              // Same back-to-modules navigation every other scene's
              // SceneTopHeader already has — this scene's header is a
              // separate widget (its own blue/progress-bar styling
              // predates SceneTopHeader), so it needs its own back button
              // rather than inheriting one.
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Expanded(
                child: Text(
                  'The Approach',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.05, 1),
                  minHeight: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.35),
                  color: _kApproachCyan,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentStep / $totalSteps',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        size: 18,
                        color: _kApproachBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── NPC Rive sprite ────────────────────────────────────────────────────────

/// Plays an NPC's .riv animation. Owns its own [FileLoader], created once in
/// [initState] rather than inline in a parent build() — RiveWidgetBuilder
/// reloads the file whenever it's handed a new (by-equality) FileLoader
/// instance, and this scene's build() runs on every message/state change.
// NpcRiveSprite now lives in shared_widgets.dart (shared with
// Scene1OfficePies's setting-introduction overlay).

// ── Multi-speaker turn grouping ─────────────────────────────────────────────

/// One consecutive run of lines from the same speaker within a turn (e.g.
/// two lines in a row from "Dr. Cruz" become one block; a Narrator line in
/// between two of Julia's lines splits them into three blocks). Built by
/// [_buildSpeakerBlocks] and rendered by [_SpeakerBlockWidget].
class _SpeakerBlock {
  final String key;
  final String displayName;
  final bool isNarrator;
  final String? spriteAsset;
  final List<String> lines;
  // Known characters named within a Narrator line's own text (narration has
  // no speaker prefix to match against, so this is matched against the
  // line content instead) — e.g. "Sir Reyes nods. Ma'am Lopez listens."
  // names two professors. Shown as a small avatar row above the narration
  // instead of leaving a reaction beat with nobody pictured.
  final List<String> narratorSprites;
  // Same narration, split one sentence per mentioned character (sprite,
  // sentence) — e.g. [(reyesSprite, "Sir Reyes nods."), (santosSprite,
  // "Sir Santos smiles slightly."), ...]. Lets a multi-character reaction
  // beat reveal one character at a time instead of dumping the whole panel
  // on screen at once (QA: "make the npc appears then disappear so it
  // wont cramp up the scenario").
  final List<(String, String)> narratorBeats;

  _SpeakerBlock({
    required this.key,
    required this.displayName,
    required this.isNarrator,
    required this.spriteAsset,
    required this.lines,
    List<String>? narratorSprites,
    List<(String, String)>? narratorBeats,
  }) : narratorSprites = narratorSprites ?? [],
       narratorBeats = narratorBeats ?? [];
}

/// Splits a multi-character Narrator line like "Sir Reyes nods. Sir Santos
/// smiles slightly." into one (sprite, sentence) pair per character
/// mentioned. A sentence matching no known character is folded into the
/// previous beat's text (same sprite) instead of being dropped or shown
/// with nobody pictured.
List<(String, String)> _splitNarratorBeats(
  String text,
  List<NpcCharacter> npcCharacters,
) {
  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final beats = <(String, String)>[];
  for (final sentence in sentences) {
    NpcCharacter? match;
    for (final ch in npcCharacters) {
      if (ch.matches(sentence)) {
        match = ch;
        break;
      }
    }
    if (match != null) {
      beats.add((match.sprites.blink, sentence));
    } else if (beats.isNotEmpty) {
      final last = beats.removeLast();
      beats.add((last.$1, '${last.$2} $sentence'));
    }
  }
  return beats;
}

/// "User (impulse):" / "User:" lines (a couple of fsg_party/fne_stage
/// branches echo back the player's own scripted line this way) and any
/// other speaker that isn't a known NpcCharacter and isn't Narrator still
/// get their own labeled block — just without a sprite. This strips a
/// trailing parenthetical descriptor for that label, e.g. "User (impulse)"
/// -> "User".
String _fallbackSpeakerName(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final parenIndex = raw.indexOf('(');
  final base = (parenIndex >= 0 ? raw.substring(0, parenIndex) : raw).trim();
  return base;
}

/// Groups this turn's non-Hati lines into per-speaker [_SpeakerBlock]s and
/// picks each block's NPC mood via the heuristic from the task brief:
/// a character's first line this turn -> greet; a later line ending in
/// "?" -> tilt; the backend's angry-turn signal (same npc_mood flag that
/// already drives foa_supervisor's mood swap) -> frown; otherwise -> blink.
/// Mood is computed from a block's first line and applies to its one
/// avatar. [npcMoodAngryThisTurn] is `provider.npcMood == 'angry'`.
List<_SpeakerBlock> _buildSpeakerBlocks(
  ScenarioConfig config,
  List<ParsedMessage> npcParsed,
  bool npcMoodAngryThisTurn,
) {
  final blocks = <_SpeakerBlock>[];
  final seenCharacterIds = <String>{};
  String? currentKey;
  _SpeakerBlock? current;

  for (final p in npcParsed) {
    final text = p.text.trim();
    if (text.isEmpty) continue;

    final rawSpeaker = p.speaker;
    final isNarrator = isNarratorSpeaker(rawSpeaker);
    final character = isNarrator
        ? null
        : resolveNpcCharacter(config, rawSpeaker ?? '');
    final displayName = isNarrator
        ? 'Narrator'
        : (character?.displayName ?? _fallbackSpeakerName(rawSpeaker));
    final key = isNarrator ? 'narrator' : (character?.id ?? 'unk:$displayName');

    String? spriteAsset;
    if (character != null) {
      final NpcMood mood;
      if (!seenCharacterIds.contains(character.id)) {
        mood = NpcMood.greet;
      } else if (text.endsWith('?')) {
        mood = NpcMood.tilt;
      } else if (npcMoodAngryThisTurn) {
        mood = NpcMood.frown;
      } else {
        mood = NpcMood.blink;
      }
      seenCharacterIds.add(character.id);
      spriteAsset = character.sprites.forMood(mood);
    }

    List<String> mentionedSprites = const [];
    List<(String, String)> beats = const [];
    if (isNarrator) {
      final seenIds = <String>{};
      mentionedSprites = [
        for (final ch in config.npcCharacters)
          if (ch.matches(text) && seenIds.add(ch.id)) ch.sprites.blink,
      ];
      beats = _splitNarratorBeats(text, config.npcCharacters);
    }

    if (key == currentKey && current != null) {
      current.lines.add(text);
      for (final sprite in mentionedSprites) {
        if (!current.narratorSprites.contains(sprite)) {
          current.narratorSprites.add(sprite);
        }
      }
      current.narratorBeats.addAll(beats);
    } else {
      current = _SpeakerBlock(
        key: key,
        displayName: displayName,
        isNarrator: isNarrator,
        spriteAsset: spriteAsset,
        lines: [text],
        narratorSprites: mentionedSprites,
        narratorBeats: beats,
      );
      blocks.add(current);
      currentKey = key;
    }
  }
  return blocks;
}

/// Renders one [_SpeakerBlock]: a Narrator line naming known characters
/// (e.g. "Sir Reyes nods. Ma'am Lopez listens.") shows a small avatar row
/// for each of them above the italic narration, rather than no one on
/// screen; a Narrator line naming nobody stays plain narration. Every other
/// speaker gets a name-labeled bubble with their small mood sprite beside
/// it, mirroring how Hati's own avatar always accompanies Hati's bubble
/// elsewhere in this scene, just at a smaller size so several speakers can
/// stack in one turn without dominating the screen.
class _SpeakerBlockWidget extends StatelessWidget {
  final _SpeakerBlock block;
  final double avatarSize;

  /// True for the scenarios whose avatar was enlarged to match
  /// foa_supervisor's sizing — at that size, the default side-by-side Row
  /// squeezed the bubble's available width down to almost nothing (since
  /// the now-much-wider sprite ate most of the row), forcing it into a
  /// tall, narrow wrap that got clipped by the scene below. Stacking the
  /// bubble above the sprite instead — foa_supervisor's own actual layout
  /// — gives it the full row width and matches foa's look completely, not
  /// just its avatar size.
  final bool stackVertically;

  /// False suppresses this block's own sprite even if [block] has one —
  /// used by the caller for a single-NPC scenario (fsn_seat, phys_jeepney)
  /// where a Narrator line in the middle of a turn splits the same
  /// character's dialogue into two+ blocks (see _buildSpeakerBlocks' own
  /// doc comment); repeating her full-size portrait once per block stacked
  /// them into a tall, cluttered column. Only the turn's last block shows
  /// the sprite there — see the call site's showSprite computation.
  final bool showSprite;

  const _SpeakerBlockWidget({
    required this.block,
    this.avatarSize = defaultAvatarSize,
    this.stackVertically = false,
    this.showSprite = true,
  });

  static const double defaultAvatarSize = 130;
  static const double _narratorAvatarSize = 56;

  @override
  Widget build(BuildContext context) {
    final text = block.lines.join('\n');
    if (block.isNarrator) {
      // Only for a narration line naming SEVERAL characters at once (e.g.
      // "Sir Reyes nods. Sir Santos smiles. Sir Cruz remains stern...") —
      // that's flavor text with no dedicated speaking line of its own per
      // person, so showing them here is the only place they'd appear. A
      // single-name mention (e.g. "The stranger removes one earbud.") is
      // usually right next to that same character's own speaker block,
      // which already shows their avatar — an avatar here too would just
      // be a confusing duplicate of the same character right below it.
      if (block.narratorSprites.length <= 1) {
        return _CharacterSpeechBubble(text: text, italic: true);
      }
      // Several characters react in the same narration beat (e.g. a
      // 5-professor panel) — reveal one at a time (sprite fades in, holds,
      // fades out, next one takes its place) instead of showing every
      // sprite and the whole combined paragraph at once, which cramped the
      // scene and made it unclear which line belonged to which reaction.
      return _SequentialNarratorReveal(
        beats: block.narratorBeats.isNotEmpty
            ? block.narratorBeats
            : [for (final s in block.narratorSprites) (s, text)],
        avatarSize: _narratorAvatarSize,
      );
    }
    final spriteAsset = showSprite ? block.spriteAsset : null;
    final bubble = _CharacterSpeechBubble(
      text: text,
      nameLabel: block.displayName.isNotEmpty ? block.displayName : null,
    );
    final sprite = spriteAsset == null
        ? null
        : (spriteAsset.endsWith('.riv')
              ? NpcRiveSprite(
                  key: ValueKey('${block.key}:$spriteAsset'),
                  assetPath: spriteAsset,
                  height: avatarSize,
                )
              : Image.asset(
                  spriteAsset,
                  height: avatarSize,
                  fit: BoxFit.contain,
                ));

    if (stackVertically) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bubble,
          if (sprite != null) ...[const SizedBox(height: 8), sprite],
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: bubble),
        if (sprite != null) ...[const SizedBox(width: 8), sprite],
      ],
    );
  }
}

/// Auto-advances through a multi-character narration one (sprite, sentence)
/// pair at a time — each shown for a few seconds, faded out, replaced by
/// the next — instead of dumping every character and the whole combined
/// paragraph on screen together. Stops on the last beat (stays visible)
/// rather than disappearing once the cycle finishes, so there's still
/// something to read afterward. Respects the scene's existing 2x speed
/// toggle, same as Hati's own typewriter effect.
class _SequentialNarratorReveal extends StatefulWidget {
  final List<(String, String)> beats;
  final double avatarSize;

  const _SequentialNarratorReveal({
    required this.beats,
    required this.avatarSize,
  });

  @override
  State<_SequentialNarratorReveal> createState() =>
      _SequentialNarratorRevealState();
}

class _SequentialNarratorRevealState extends State<_SequentialNarratorReveal> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  @override
  void didUpdateWidget(covariant _SequentialNarratorReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.beats != oldWidget.beats) {
      _index = 0;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_index >= widget.beats.length - 1) return;
    final sentence = widget.beats[_index].$2;
    // Roughly reading-time-scaled (base + per-character), clamped to a
    // sane range so a short "Sir Cruz nods." and a longer sentence both
    // get an appropriate hold before advancing.
    final baseMs = 1400 + sentence.length * 35;
    final clampedMs = baseMs.clamp(1800, 4200);
    final ms = HatiSpeechSpeedController.isFast.value
        ? clampedMs ~/ 2
        : clampedMs;
    _timer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _index++);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.beats.isEmpty) return const SizedBox.shrink();
    final (sprite, sentence) = widget.beats[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: sprite.endsWith('.riv')
                ? NpcRiveSprite(assetPath: sprite, height: widget.avatarSize)
                : Image.asset(
                    sprite,
                    height: widget.avatarSize,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: _CharacterSpeechBubble(text: sentence, italic: true),
          ),
        ),
      ],
    );
  }
}

// ── Character speech bubble (prof / user) ─────────────────────────────────────

class _CharacterSpeechBubble extends StatelessWidget {
  final String text;
  final String? nameLabel;
  final bool italic;

  const _CharacterSpeechBubble({
    required this.text,
    this.nameLabel,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.55,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (nameLabel != null && nameLabel!.isNotEmpty) ...[
              Text(
                nameLabel!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _kApproachBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom input bar ──────────────────────────────────────────────────────────

/// The "write your own" option at the end of the choice sheet's option
/// list — a lighter outlined style (pencil icon, no lettered badge) than
/// the [ScriptOptionCard]s above it so it reads as "compose something new"
/// rather than "option D".
class _CustomResponseCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _CustomResponseCard({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: _kApproachBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kApproachBlue.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kApproachBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: _kApproachBlue,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Write your own response',
                    style: TextStyle(
                      color: _kApproachBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApproachInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isRecording;
  final bool isTranscribing;
  final String hintText;
  final VoidCallback onSend;
  final VoidCallback onMicTap;

  const _ApproachInputBar({
    required this.controller,
    required this.enabled,
    required this.isRecording,
    this.isTranscribing = false,
    required this.hintText,
    required this.onSend,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    // SafeArea(top: false) — without it, a phone using gesture navigation
    // (no physical/on-screen button bar reserving its own space) draws its
    // nav bar directly on top of this fixed 12px bottom padding, covering
    // part of the text field and send button. The sibling single-button
    // "Continue" branch right below this one in scene3_interaction.dart
    // already wraps in SafeArea for the same reason.
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: isTranscribing
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: _kApproachBlue,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          isRecording
                              ? Icons.stop_circle_rounded
                              : Icons.mic_none_rounded,
                          color: isRecording
                              ? Colors.red
                              : (enabled ? _kApproachBlue : Colors.grey),
                          size: 28,
                        ),
                        onPressed: (enabled || isRecording) ? onMicTap : null,
                      ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  onSubmitted: enabled ? (_) => onSend() : null,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF0F0F0),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: enabled ? _kApproachBlue : Colors.grey,
                ),
                onPressed: enabled ? onSend : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
