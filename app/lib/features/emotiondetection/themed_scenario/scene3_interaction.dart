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

import 'dart:ui';

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
    // Narration ("You notice someone standing next to you.") is
    // scene-setting flavor text, not something a character says — it used
    // to get concatenated straight into whichever NPC bubble was on screen
    // that turn (and, in the multi-speaker layout, rendered as just another
    // bubble in the same vertical list), which blurred the two together.
    // Split it out here so it can render as its own banner over the top of
    // the scene frame instead — see _ScenarioFrame/_NarrationBanner below.
    final narratorParsed = npcParsed
        .where((p) => isNarratorSpeaker(p.speaker))
        .toList();
    final actualNpcParsed = npcParsed
        .where((p) => !isNarratorSpeaker(p.speaker))
        .toList();
    final narrationText = narratorParsed
        .map((p) => p.text.trim())
        .where((t) => t.isNotEmpty)
        .join(' ');
    // Known characters named within this turn's narration (e.g. "Sir Reyes
    // nods. Ma'am Lopez listens.") — shown as a small avatar row inside the
    // narration banner instead of leaving a reaction beat with nobody
    // pictured.
    final narrationSprites = <String>[
      for (final ch in config.npcCharacters)
        if (ch.matches(narrationText)) ch.sprites.blink,
    ];

    // config.npcCharacters is only populated for the 5 multi/single-NPC
    // scenarios (fbop_spotlight, fne_stage, fsg_party, fsn_seat,
    // phys_jeepney) — see scenario_models.dart. Every other scenario
    // (foa_supervisor, foa_classroom) keeps the original single-bubble +
    // single-big-sprite rendering further below, untouched.
    final useMultiSpeakerLayout = config.npcCharacters.isNotEmpty;
    final speakerBlocks = useMultiSpeakerLayout
        ? _buildSpeakerBlocks(
            config,
            actualNpcParsed,
            provider.npcMood == 'angry',
          )
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
        : actualNpcParsed
              .map((p) => p.text)
              .where((t) => t.trim().isNotEmpty)
              .join('\n\n');
    // fsg_party/fsn_seat/phys_jeepney's NPC avatar matches foa_supervisor's
    // stacked (bubble-above-sprite) layout by request — fbop_spotlight and
    // fne_stage keep the default side-by-side Row — see
    // _SpeakerBlockWidget.stackVertically. Actual sizes are computed further
    // down, relative to the frame's own (cropped, no longer full-screen)
    // height rather than the whole device screen.
    const matchFoaSizeKeys = {'fsg_party', 'fsn_seat', 'phys_jeepney'};
    final matchesFoaLayout = matchFoaSizeKeys.contains(config.scenarioKey);
    final hatiText = hatiLines.join('\n\n');
    final isTextInput = provider.ui.type == ScenarioUIType.textInput;

    final bubbleKey = '$step:$hatiText';
    if (bubbleKey != _trackedBubbleKey) {
      _trackedBubbleKey = bubbleKey;
      _dialogueComplete = false;
    }
    // No Hati line to wait for on this turn -> nothing blocks "Continue".
    final dialogueReady = hatiText.isEmpty || _dialogueComplete;

    return Scaffold(
      // The scenario's own art now lives inside a cropped, rounded "frame"
      // instead of filling the whole screen (see _ScenarioFrame) — the area
      // below it keeps this solid blue, reserved for Hati alone, so the
      // frog can never end up floating over (and hiding) an NPC's speech
      // bubble the way it could when both shared one overlapping Stack.
      backgroundColor: _kApproachBlue,
      body: HatiTapToAdvance(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // 3 of 7 — the same shared scene numbering every other
                  // scene's SceneTopHeader uses (1=Office, 2=Preparation,
                  // 4=Debrief, 5=Coping, 6=Closing). Previously this varied
                  // by step name within Interaction itself (0.15/0.55/0.9),
                  // fractions that didn't correspond to anything real.
                  const _ApproachTopBar(currentStep: 3, totalSteps: 7),
                  const SceneSpeedToggleRow(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Hati's own zone stays a fixed slice of whatever
                        // vertical space is actually left (recomputed here
                        // on every build, so it shrinks along with
                        // everything else once the on-screen keyboard opens
                        // for a text-input turn) — never more than ~200px,
                        // never so little the frog+bubble can't fit even
                        // scaled down (HatiSpeakingBlock's own FittedBox
                        // handles that).
                        final availableHeight = constraints.maxHeight;
                        final hatiZoneHeight = (availableHeight * 0.26).clamp(
                          130.0,
                          200.0,
                        );
                        final frameHeight = (availableHeight - hatiZoneHeight)
                            .clamp(120.0, availableHeight);
                        // NPC avatars scale off the frame's own height, not
                        // the full device screen — the frame used to BE the
                        // full screen, so the old sceneHeight-based sizing
                        // read fine there; now that it's a smaller cropped
                        // region, that same fraction would dwarf it. This
                        // keeps every scenario's character sized
                        // consistently relative to its own frame instead of
                        // varying with how tall the device happens to be.
                        final npcAvatarSize = matchesFoaLayout
                            ? (frameHeight * 0.42).clamp(90.0, 170.0)
                            : (frameHeight * 0.3).clamp(72.0, 130.0);

                        return Column(
                          children: [
                            SizedBox(
                              height: frameHeight,
                              child: _ScenarioFrame(
                                backgroundAsset: config.backgroundAsset,
                                narrationText: narrationText,
                                narrationSprites: narrationSprites,
                                lastSentText: _lastSentText,
                                content: useMultiSpeakerLayout
                                    ? _MultiSpeakerContent(
                                        speakerBlocks: speakerBlocks,
                                        avatarSize: npcAvatarSize,
                                        stackVertically: matchesFoaLayout,
                                        singleNpcCharacter:
                                            needsSingleNpcFallback
                                            ? singleNpcCharacter
                                            : null,
                                      )
                                    : _SingleNpcContent(
                                        text: profText,
                                        spriteAsset: activeSpriteAsset,
                                        spriteSize: npcAvatarSize,
                                      ),
                              ),
                            ),
                            SizedBox(
                              height: hatiZoneHeight,
                              child: _HatiZone(
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
                  else if (isTextInput)
                    PopIn(
                      key: ValueKey(bubbleKey),
                      child: _ApproachInputBar(
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
              // Difficult Mode's branch points (e.g. "Sorry, I just wanted
              // to..." / "Never mind." / continue angrily / custom) send
              // several real choices, not one default "Continue" — show
              // every option instead of silently only offering the first. A
              // draggable sheet overlaying the whole scene (matching
              // HatiSceneShell's own header+choices sheet everywhere else)
              // rather than a fixed-size panel, so the header and the
              // option cards drag up together as one unit.
              if (dialogueReady &&
                  !isTextInput &&
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
                        for (var i = 0; i < provider.ui.options.length; i++)
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
                      ],
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

// ── Hati zone: its own solid-blue area below the scenario frame ────────────
/// Hati's frog + bubble live in a dedicated strip below [_ScenarioFrame],
/// never overlapping it — the old version floated the frog directly over
/// the NPC dialogue in a shared Stack, which meant a long NPC turn (or a
/// wide bubble) could end up hidden behind the frog. Keeping them in
/// separate layout slots makes that structurally impossible instead of
/// just visually unlikely.
class _HatiZone extends StatelessWidget {
  final bool showBubble;
  final String message;
  final String bubbleKey;
  final double frogSize;
  final VoidCallback? onSequenceComplete;

  const _HatiZone({
    required this.showBubble,
    required this.message,
    required this.bubbleKey,
    this.frogSize = 100,
    this.onSequenceComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: const BoxDecoration(
        color: _kApproachBlue,
        // A visible seam between the cropped art above and Hati's own zone
        // — the "below portion is Hati's" split the reference calls for —
        // instead of the frame's rounded corners just trailing off into
        // flat blue.
        border: Border(top: BorderSide(color: Color(0x33FFFFFF), width: 1)),
      ),
      // FittedBox guarantees the frog+bubble always fit within whatever
      // height this zone is actually given, scaling down instead of
      // overflowing — the caller already caps that height for extreme
      // cases (keyboard open, a long Hati line).
      child: Align(
        alignment: Alignment.bottomLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: HatiLayout.bubbleMaxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBubble && message.isNotEmpty)
                  HatiSpeakingBlock(
                    key: ValueKey(bubbleKey),
                    persistentMessage: message,
                    frogSize: frogSize,
                    mood: HatiMood.encourage,
                    // Fades the bubble out on its own a few seconds after it
                    // finishes typing, leaving just the frog — it used to
                    // stay put indefinitely until the player tapped.
                    // autoAdvance adds this timeout as a fallback only —
                    // tapping still dismisses it (or fast-forwards it while
                    // typing) immediately, same as before.
                    dissolveBubble: true,
                    autoAdvance: true,
                    holdAfterTyping: const Duration(seconds: 3),
                    onSequenceComplete: onSequenceComplete,
                  )
                else
                  HatiFrogAvatar(size: frogSize, mood: HatiMood.encourage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scenario frame: cropped art + narration banner + NPC dialogue ──────────
/// The scenario's own art, cropped to a fixed-height rounded frame instead
/// of filling the whole screen. Narration renders as its own banner pinned
/// to the frame's top edge (see [_NarrationBanner]) — no longer folded into
/// whichever NPC bubble happened to be on screen that turn — while the
/// NPC's own dialogue ([content]) anchors to the bottom edge, scrolling
/// internally if a long turn doesn't fit.
class _ScenarioFrame extends StatelessWidget {
  final String backgroundAsset;
  final String narrationText;
  final List<String> narrationSprites;
  final String? lastSentText;
  final Widget content;

  const _ScenarioFrame({
    required this.backgroundAsset,
    required this.narrationText,
    required this.narrationSprites,
    required this.content,
    this.lastSentText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(backgroundAsset, fit: BoxFit.cover),
            // Legibility scrims: a soft fade at the top for the narration
            // banner, another at the bottom for whatever dialogue sits
            // there — the art itself is never darkened outside those bands.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x77000000), Colors.transparent],
                    stops: [0.0, 0.32],
                  ),
                ),
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x77000000), Colors.transparent],
                    stops: [0.0, 0.42],
                  ),
                ),
              ),
            ),
            if (narrationText.isNotEmpty)
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: _NarrationBanner(
                  text: narrationText,
                  mentionedSprites: narrationSprites,
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.32,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      content,
                      if (lastSentText != null && lastSentText!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _CharacterSpeechBubble(
                            text: lastSentText!,
                            alignEnd: false,
                          ),
                        ),
                      ],
                    ],
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

/// Scene-setting narration ("You notice someone standing next to you.") —
/// its own banner pinned above the frame's content instead of being folded
/// into whichever NPC bubble happens to be on screen that turn.
class _NarrationBanner extends StatelessWidget {
  final String text;
  final List<String> mentionedSprites;

  const _NarrationBanner({
    required this.text,
    this.mentionedSprites = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mentionedSprites.isNotEmpty) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final sprite in mentionedSprites) ...[
                      ClipOval(
                        child: sprite.endsWith('.riv')
                            ? NpcRiveSprite(assetPath: sprite, height: 26)
                            : Image.asset(
                                sprite,
                                height: 26,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `foa_supervisor`/`foa_classroom`'s single-sprite layout: one NPC bubble
/// plus (optionally) their static/Rive art beneath it.
class _SingleNpcContent extends StatelessWidget {
  final String text;
  final String? spriteAsset;
  final double spriteSize;

  const _SingleNpcContent({
    required this.text,
    required this.spriteAsset,
    required this.spriteSize,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty && spriteAsset == null) return const SizedBox.shrink();
    final sprite = spriteAsset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text.isNotEmpty) _CharacterSpeechBubble(text: text),
        if (sprite != null) ...[
          const SizedBox(height: 8),
          // NPC art is either a static image or a Rive animation (.riv) —
          // Image.asset can't decode Rive's binary format, so branch by
          // extension. Keyed by asset path so switching between the
          // default and angry sprite (different widget subtrees/state)
          // rebuilds cleanly.
          sprite.endsWith('.riv')
              ? NpcRiveSprite(
                  key: ValueKey(sprite),
                  assetPath: sprite,
                  height: spriteSize,
                )
              : Image.asset(sprite, height: spriteSize, fit: BoxFit.contain),
        ],
      ],
    );
  }
}

/// The 5 multi/single-NPC scenarios' layout: one visually distinct block
/// per speaker who talked this turn (name label + bubble + mood sprite —
/// see [_SpeakerBlockWidget]), falling back to a single NPC's idle sprite
/// on a turn where she's only mentioned in narration rather than speaking.
class _MultiSpeakerContent extends StatelessWidget {
  final List<_SpeakerBlock> speakerBlocks;
  final double avatarSize;
  final bool stackVertically;
  final NpcCharacter? singleNpcCharacter;

  const _MultiSpeakerContent({
    required this.speakerBlocks,
    required this.avatarSize,
    required this.stackVertically,
    this.singleNpcCharacter,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = singleNpcCharacter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final block in speakerBlocks) ...[
          _SpeakerBlockWidget(
            block: block,
            avatarSize: avatarSize,
            stackVertically: stackVertically,
          ),
          const SizedBox(height: 10),
        ],
        if (fallback != null)
          Align(
            alignment: Alignment.centerRight,
            child: fallback.sprites.blink.endsWith('.riv')
                ? NpcRiveSprite(
                    assetPath: fallback.sprites.blink,
                    height: avatarSize,
                  )
                : Image.asset(
                    fallback.sprites.blink,
                    height: avatarSize,
                    fit: BoxFit.contain,
                  ),
          ),
      ],
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────
/// Sits directly on the scaffold's own solid blue (not over any art, which
/// now only appears inside [_ScenarioFrame] below it) — a plain darker-blue
/// card reads better here than a glass/blur treatment, which would have
/// nothing but flat color behind it to blur.
class _ApproachTopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _ApproachTopBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The Approach',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.05, 1),
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      color: _kApproachCyan,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$currentStep/$totalSteps',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline,
                size: 16,
                color: _kApproachBlue,
              ),
            ),
          ],
        ),
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
/// two lines in a row from "Dr. Cruz" become one block). Narrator lines are
/// filtered out before this ever runs (see [_NarrationBanner] instead), so
/// every block here is an actual character. Built by [_buildSpeakerBlocks]
/// and rendered by [_SpeakerBlockWidget].
class _SpeakerBlock {
  final String key;
  final String displayName;
  final String? spriteAsset;
  final List<String> lines;

  _SpeakerBlock({
    required this.key,
    required this.displayName,
    required this.spriteAsset,
    required this.lines,
  });
}

/// "User (impulse):" / "User:" lines (a couple of fsg_party/fne_stage
/// branches echo back the player's own scripted line this way) and any
/// other speaker that isn't a known NpcCharacter still get their own
/// labeled block — just without a sprite. This strips a trailing
/// parenthetical descriptor for that label, e.g. "User (impulse)" -> "User".
String _fallbackSpeakerName(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final parenIndex = raw.indexOf('(');
  final base = (parenIndex >= 0 ? raw.substring(0, parenIndex) : raw).trim();
  return base;
}

/// Groups this turn's NPC lines (narration already filtered out by the
/// caller) into per-speaker [_SpeakerBlock]s and picks each block's NPC
/// mood via the heuristic from the task brief: a character's first line
/// this turn -> greet; a later line ending in "?" -> tilt; the backend's
/// angry-turn signal (same npc_mood flag that already drives
/// foa_supervisor's mood swap) -> frown; otherwise -> blink. Mood is
/// computed from a block's first line and applies to its one avatar.
/// [npcMoodAngryThisTurn] is `provider.npcMood == 'angry'`.
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
    final character = resolveNpcCharacter(config, rawSpeaker ?? '');
    final displayName =
        character?.displayName ?? _fallbackSpeakerName(rawSpeaker);
    final key = character?.id ?? 'unk:$displayName';

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

    if (key == currentKey && current != null) {
      current.lines.add(text);
    } else {
      current = _SpeakerBlock(
        key: key,
        displayName: displayName,
        spriteAsset: spriteAsset,
        lines: [text],
      );
      blocks.add(current);
      currentKey = key;
    }
  }
  return blocks;
}

/// Renders one [_SpeakerBlock]: a name-labeled bubble with the speaker's
/// small mood sprite beside it, mirroring how Hati's own avatar always
/// accompanies Hati's bubble elsewhere in this scene, just at a smaller
/// size so several speakers can stack in one turn without dominating the
/// screen.
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

  const _SpeakerBlockWidget({
    required this.block,
    this.avatarSize = defaultAvatarSize,
    this.stackVertically = false,
  });

  static const double defaultAvatarSize = 130;

  @override
  Widget build(BuildContext context) {
    final text = block.lines.join('\n');
    final spriteAsset = block.spriteAsset;
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

// ── Character speech bubble (prof / user) ─────────────────────────────────────

class _CharacterSpeechBubble extends StatelessWidget {
  final String text;
  final bool alignEnd;
  final String? nameLabel;

  const _CharacterSpeechBubble({
    required this.text,
    this.alignEnd = true,
    this.nameLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.55,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
              crossAxisAlignment: alignEnd
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (nameLabel != null && nameLabel!.isNotEmpty) ...[
                  Text(
                    nameLabel!,
                    textAlign: alignEnd ? TextAlign.right : TextAlign.left,
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
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          // Small diamond nub, tucked under the near-side corner of the
          // bubble, pointing down toward the speaker sitting below it —
          // same white fill + shadow as the bubble itself so it reads as
          // one continuous shape rather than a separate sticker.
          Positioned(
            bottom: -5,
            left: alignEnd ? null : 18,
            right: alignEnd ? 18 : null,
            child: Transform.rotate(
              angle: 0.785398, // 45°
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom input bar ──────────────────────────────────────────────────────────

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
    return Container(
      color: Colors.white,
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
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
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
    );
  }
}
