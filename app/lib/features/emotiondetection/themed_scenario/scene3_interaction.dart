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

  double _progressForStep(String? step, ScenarioUIType uiType) {
    if (step == 'foa_s3_npc') return 0.15;
    if (step == 'foa_s3_reaction' && uiType == ScenarioUIType.textInput) {
      return 0.55;
    }
    return 0.9;
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
      backgroundColor: _kApproachBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ApproachTopBar(progress: _progressForStep(step, provider.ui.type)),
            const SceneSpeedToggleRow(),
            Expanded(
              // Explicit flex (rather than the implicit 1 this used to
              // rely on) now that the multi-option choice panel below is
              // also Expanded when it's showing — they split the
              // remaining space by ratio instead of the panel being free
              // to size itself to however many options there are.
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    config.backgroundAsset,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  // A real flex layout, not two independently-floating
                  // Positioned regions each guessing how tall the other is:
                  // the scrollable dialogue area gets whatever space is left
                  // over after the Hati lane below it takes what it
                  // actually needs (which varies with message length). That
                  // guarantees they can never visually collide — no fixed
                  // pixel reserve to get wrong for a longer message. Only
                  // the scrollable area is inset — the Hati lane keeps its
                  // own edge-to-edge gradient background, same as before.
                  Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 4,
                            top: 12,
                          ),
                          child: SingleChildScrollView(
                            // Anchored to the TOP, not the bottom — the
                            // NPC's own line renders first in this column,
                            // the player's echoed last message after it.
                            // With reverse:true (the old setting) a long
                            // turn auto-scrolled to keep the echo in view
                            // and pushed the NPC's actual line off the top
                            // instead — backwards, since the echo is just
                            // what the player already knows they typed,
                            // while the NPC's line is the whole point.
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // NPC content comes first (top); the user's
                                // own last message renders below it, in its
                                // own left-aligned row, instead of the two
                                // sitting side-by-side — keeps a long NPC
                                // turn from squeezing the user's bubble down
                                // to a sliver, and reads top-to-bottom like
                                // a normal chat log.
                                ...useMultiSpeakerLayout
                                    ? [
                                        // One visually distinct block per
                                        // speaker run this turn: name label
                                        // + bubble, plus that character's
                                        // small mood sprite (see
                                        // _SpeakerBlockWidget below) — so in
                                        // e.g. the 5-professor panel it's
                                        // always clear who said which line.
                                        for (final block in speakerBlocks) ...[
                                          _SpeakerBlockWidget(block: block),
                                          const SizedBox(height: 10),
                                        ],
                                        if (needsSingleNpcFallback)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child:
                                                singleNpcCharacter.sprites.blink
                                                    .endsWith('.riv')
                                                ? NpcRiveSprite(
                                                    assetPath:
                                                        singleNpcCharacter
                                                            .sprites
                                                            .blink,
                                                    height: 84,
                                                  )
                                                : Image.asset(
                                                    singleNpcCharacter
                                                        .sprites
                                                        .blink,
                                                    height: 84,
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
                                          // NPC art is either a static image
                                          // or a Rive animation (.riv) —
                                          // Image.asset can't decode Rive's
                                          // binary format, so branch by
                                          // extension. Keyed by asset path
                                          // so switching between the
                                          // default and angry sprite
                                          // (different widget subtrees/
                                          // state) rebuilds cleanly.
                                          activeSpriteAsset.endsWith('.riv')
                                              ? NpcRiveSprite(
                                                  key: ValueKey(
                                                    activeSpriteAsset,
                                                  ),
                                                  assetPath: activeSpriteAsset,
                                                  height: sceneHeight * 0.34,
                                                )
                                              : Image.asset(
                                                  activeSpriteAsset,
                                                  height: sceneHeight * 0.34,
                                                  fit: BoxFit.contain,
                                                ),
                                        ],
                                      ],
                                if (_lastSentText != null &&
                                    _lastSentText!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _CharacterSpeechBubble(
                                        text: _lastSentText!,
                                        alignEnd: false,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      _ApproachHatiLane(
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
                    ],
                  ),
                ],
              ),
            ),
            if (isTextInput)
              _ApproachInputBar(
                controller: _controller,
                enabled:
                    !provider.isLoading &&
                    !_isRecording &&
                    !_isTranscribing &&
                    dialogueReady,
                isRecording: _isRecording,
                isTranscribing: _isTranscribing,
                hintText: _isRecording
                    ? 'Listening…'
                    : (_isTranscribing
                          ? 'Converting your voice…'
                          : 'Type your response...'),
                onSend: () => _sendText(provider),
                onMicTap: () =>
                    _isRecording ? _stopRecording(provider) : _startRecording(),
              )
            else if (provider.ui.options.length > 1)
              // Difficult Mode's branch points (e.g. "Sorry, I just wanted
              // to..." / "Never mind." / continue angrily / custom) send
              // several real choices, not one default "Continue" — show
              // every option instead of silently only offering the first.
              // Matches Preparation's "Choose Your Script" panel exactly,
              // not just visually: Expanded (shares remaining space with
              // the scene above by flex ratio, same as HatiSceneShell's
              // coach-zone/content split) with the fixed header pinned
              // above a ScrollHintArea — the same scrollable-with-a-hint
              // list, not a container forced to reserve a big chunk of
              // screen regardless of how many options there are.
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: SectionHeader(
                            title: 'Choose Your Response',
                            subtitle: 'Select one or write your own',
                          ),
                        ),
                        Expanded(
                          child: ScrollHintArea(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                            child: Column(
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
                                    enabled:
                                        !(provider.isLoading || !dialogueReady),
                                    onTap:
                                        (provider.isLoading || !dialogueReady)
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
              )
            else
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: SafeArea(
                  top: false,
                  child: HatiButton(
                    label: provider.ui.options.isNotEmpty
                        ? provider.ui.options.first
                        : 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onTap: (provider.isLoading || !dialogueReady)
                        ? null
                        : () => provider.submitText(
                            provider.ui.options.isNotEmpty
                                ? provider.ui.options.first
                                : 'Continue',
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

// ── Hati overlay: frog + bubble above scene layers ─────────────────────────

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
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 8, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            _kApproachBlue.withValues(alpha: 0.55),
            _kApproachBlue.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            // Lets the bubble grow up to its full HatiLayout.bubbleMaxWidth
            // — it used to be a fixed SizedBox(width: frogSize + 16), just
            // enough for the frog, which squeezed the bubble down to that
            // width and made it wrap into a tall, narrow column instead of
            // using its intended width. Flexible (rather than a fixed
            // SizedBox) also means it can't overflow on a screen narrower
            // than bubbleMaxWidth — it just uses whatever's available.
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
                      // Fades the bubble out a couple seconds after it
                      // finishes typing, leaving just the frog — it used to
                      // stay put indefinitely, which could crowd out the
                      // NPC's own bubble above it in the scrollable area.
                      dissolveBubble: true,
                      onSequenceComplete: onSequenceComplete,
                    )
                  else
                    HatiFrogAvatar(size: frogSize, mood: HatiMood.encourage),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ── Top bar (reference-style) ─────────────────────────────────────────────────

class _ApproachTopBar extends StatelessWidget {
  final double progress;

  const _ApproachTopBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round().clamp(0, 100);

    return Container(
      color: _kApproachBlue,
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
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
              SizedBox(width: 48),
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
                      '$pct%',
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

  _SpeakerBlock({
    required this.key,
    required this.displayName,
    required this.isNarrator,
    required this.spriteAsset,
    required this.lines,
    List<String>? narratorSprites,
  }) : narratorSprites = narratorSprites ?? [];
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
    if (isNarrator) {
      final seenIds = <String>{};
      mentionedSprites = [
        for (final ch in config.npcCharacters)
          if (ch.matches(text) && seenIds.add(ch.id)) ch.sprites.blink,
      ];
    }

    if (key == currentKey && current != null) {
      current.lines.add(text);
      for (final sprite in mentionedSprites) {
        if (!current.narratorSprites.contains(sprite)) {
          current.narratorSprites.add(sprite);
        }
      }
    } else {
      current = _SpeakerBlock(
        key: key,
        displayName: displayName,
        isNarrator: isNarrator,
        spriteAsset: spriteAsset,
        lines: [text],
        narratorSprites: mentionedSprites,
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

  const _SpeakerBlockWidget({required this.block});

  static const double _avatarSize = 130;
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sprite in block.narratorSprites) ...[
                sprite.endsWith('.riv')
                    ? NpcRiveSprite(
                        assetPath: sprite,
                        height: _narratorAvatarSize,
                      )
                    : Image.asset(
                        sprite,
                        height: _narratorAvatarSize,
                        fit: BoxFit.contain,
                      ),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _CharacterSpeechBubble(text: text, italic: true),
        ],
      );
    }
    final spriteAsset = block.spriteAsset;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: _CharacterSpeechBubble(
            text: text,
            nameLabel: block.displayName.isNotEmpty ? block.displayName : null,
          ),
        ),
        if (spriteAsset != null) ...[
          const SizedBox(width: 8),
          spriteAsset.endsWith('.riv')
              ? NpcRiveSprite(
                  key: ValueKey('${block.key}:$spriteAsset'),
                  assetPath: spriteAsset,
                  height: _avatarSize,
                )
              : Image.asset(
                  spriteAsset,
                  height: _avatarSize,
                  fit: BoxFit.contain,
                ),
        ],
      ],
    );
  }
}

// ── Character speech bubble (prof / user) ─────────────────────────────────────

class _CharacterSpeechBubble extends StatelessWidget {
  final String text;
  final bool alignEnd;
  final String? nameLabel;
  final bool italic;

  const _CharacterSpeechBubble({
    required this.text,
    this.alignEnd = true,
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
