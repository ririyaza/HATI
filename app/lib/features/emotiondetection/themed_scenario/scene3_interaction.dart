// ─────────────────────────────────────────────
// HATI – Scene 3: The Approach & NPC Interaction
// screens/scene3_interaction.dart
//
// Visual-novel "stage" redesign: a fixed background-art stage with Hati
// pinned bottom-left and the active NPC pinned bottom-right, playing one
// speech bubble/caption at a time in strict order (Hati -> narration/NPC
// lines -> input), plus a one-time-per-run input-medium picker (voice/
// type/both) shown before the scene's first turn.
//
// NPC dialogue and Hati's coaching text are read directly from
// provider.messages every turn, parsed by speaker prefix (e.g.
// "**Professor:**" / "**Narrator:**" / "**Hati:**") via parseSpeakerMessage.
//
// Background art and (optional) character sprite come from
// provider.config, generalized per scenario: `foa_supervisor` keeps its
// bespoke classroom + professor sprite art (treated as a single implicit
// NPC); every other scenario with `npcCharacters` renders one on-stage
// character at a time, swapping in the same slot; `foa_classroom` has no
// sprite art at all, so its speakers get a name tag instead of a portrait.
//
// This scene also owns its own AudioRecorder (record package, WAV/16kHz/
// mono), mirroring scenario_game.dart's pattern but not sharing code with
// it. Voice input is only offered while the backend expects free text
// (ui.type == text_input) or on the "Write your own response" custom path.
// ─────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../shared/audio/hati_audio_service.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

const _kApproachBlue = Color(0xFF4A8FD4);

/// When true, every beat (Hati's, narration, NPC) advances itself after a
/// reading-time hold instead of waiting for a tap. Off by default —
/// player-paced dialogue, matching every other scene.
const _kAutoAdvanceBeats = false;

/// Stable synthetic "character id" for foa_supervisor, the one scenario
/// that has a single sprite (`config.spriteAsset`/`spriteAssetAngry`)
/// instead of a `config.npcCharacters` list — treated as one implicit NPC
/// occupying the stage's NPC slot like any other.
const _kFoaSupervisorImplicitId = 'foa_supervisor_implicit';

// ── Beats ────────────────────────────────────────────────────────────────

enum _BeatKind { hati, narrator, npc }

/// One unit of the turn's dialogue, played in strict order by the beat
/// director in [_Scene3InteractionState]. `narrator` beats with a null
/// [characterId] are plain captions (no one named); a non-null
/// [characterId] means the narration named a character, who appears on
/// stage like an `npc` beat while this caption plays.
class _Beat {
  final _BeatKind kind;
  final String text;
  final String? characterId;
  final String? displayName;
  final String? spriteAsset;

  const _Beat({
    required this.kind,
    required this.text,
    this.characterId,
    this.displayName,
    this.spriteAsset,
  });
}

/// Splits a multi-character Narrator line like "Sir Reyes nods. Sir Santos
/// smiles slightly." into one (character, sentence) pair per character
/// mentioned. A sentence matching no known character is folded into the
/// previous beat's text (same character) instead of being dropped or shown
/// with nobody named.
List<(NpcCharacter, String)> _splitNarratorBeats(
  String text,
  List<NpcCharacter> npcCharacters,
) {
  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final beats = <(NpcCharacter, String)>[];
  for (final sentence in sentences) {
    NpcCharacter? match;
    for (final ch in npcCharacters) {
      if (ch.matches(sentence)) {
        match = ch;
        break;
      }
    }
    if (match != null) {
      beats.add((match, sentence));
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
/// get their own labeled beat — just without a sprite. Strips a trailing
/// parenthetical descriptor, e.g. "User (impulse)" -> "User".
String _fallbackSpeakerName(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final parenIndex = raw.indexOf('(');
  final base = (parenIndex >= 0 ? raw.substring(0, parenIndex) : raw).trim();
  return base;
}

/// Same expression-cue keywords as scenario_engine.py's `_detect_npc_mood`
/// (frown/glare/stern/annoyed/etc.) — checked here per LINE rather than
/// relying solely on the backend's turn-wide `npc_mood` flag.
final _npcMoodAngryPatterns = [
  RegExp(r'\bfrown(s|ed|ing)?\b', caseSensitive: false),
  RegExp(r'\bglare(s|d)?\b', caseSensitive: false),
  RegExp(r'\bscowl(s|ed)?\b', caseSensitive: false),
  RegExp(r'\bstern\b', caseSensitive: false),
  RegExp(r'\bharden(s|ed)?\b', caseSensitive: false),
  RegExp(r'\bannoyed\b', caseSensitive: false),
  RegExp(r'\birritated\b', caseSensitive: false),
  RegExp(r'\bhostile\b', caseSensitive: false),
  RegExp(r'\bimpatient\b', caseSensitive: false),
  RegExp(r'\bunimpressed\b', caseSensitive: false),
  RegExp(r'\bdisapprov\w*\b', caseSensitive: false),
  RegExp(r'\bexasperat\w*\b', caseSensitive: false),
  RegExp(r'\bsnaps?\b', caseSensitive: false),
  RegExp(r'\bnarrows?\s+\w+\s+eyes\b', caseSensitive: false),
  RegExp(r'\bcrosses?\s+\w+\s+arms\b', caseSensitive: false),
  RegExp(r'\braises?\s+\w+\s+voice\b', caseSensitive: false),
  RegExp(r'\bclench\w*\s+\w+\s+(jaw|fist)\b', caseSensitive: false),
  RegExp(r'\brolls?\s+\w+\s+eyes\b', caseSensitive: false),
];

bool _lineIndicatesAngryMood(String text) =>
    _npcMoodAngryPatterns.any((p) => p.hasMatch(text));

/// Builds this turn's ordered beat list: Hati first (if he has a line),
/// then every Narrator/NPC beat in backend order, one beat per
/// consecutive same-speaker run (mirroring the mood heuristic: a
/// character's first line this turn -> greet, a later line ending in "?"
/// -> tilt, an angry-cue line or `npcMoodAngryThisTurn` -> frown, else
/// blink).
List<_Beat> _buildBeats({
  required ScenarioConfig config,
  required List<ParsedMessage> parsed,
  required String? activeSpriteAsset,
  required bool npcMoodAngryThisTurn,
}) {
  final beats = <_Beat>[];

  final hatiText = parsed
      .where((p) => isHatiSpeaker(p.speaker))
      .map((p) => p.text)
      .where((t) => t.trim().isNotEmpty)
      .join('\n\n');
  if (hatiText.isNotEmpty) {
    beats.add(_Beat(kind: _BeatKind.hati, text: hatiText));
  }

  final npcParsed = parsed.where((p) => !isHatiSpeaker(p.speaker)).toList();

  if (config.npcCharacters.isEmpty) {
    if (config.spriteAsset != null) {
      // foa_supervisor: single implicit NPC — merge all non-Hati text into
      // one beat, same as the scene's original monolithic rendering.
      final profText = npcParsed
          .map((p) => p.text)
          .where((t) => t.trim().isNotEmpty)
          .join('\n\n');
      if (profText.isNotEmpty || activeSpriteAsset != null) {
        beats.add(
          _Beat(
            kind: _BeatKind.npc,
            text: profText,
            characterId: _kFoaSupervisorImplicitId,
            displayName: '',
            spriteAsset: activeSpriteAsset,
          ),
        );
      }
    } else {
      // foa_classroom: no sprite art at all — group consecutive
      // same-speaker lines and give each an explicit name tag, since
      // there's no portrait to identify the speaker otherwise.
      String? currentKey;
      String? currentDisplayName;
      var currentIsNarrator = false;
      final lines = <String>[];

      void flush() {
        if (lines.isEmpty) return;
        final text = lines.join('\n');
        if (currentIsNarrator) {
          beats.add(_Beat(kind: _BeatKind.narrator, text: text));
        } else {
          beats.add(
            _Beat(
              kind: _BeatKind.npc,
              text: text,
              characterId: currentKey,
              displayName: currentDisplayName,
            ),
          );
        }
        lines.clear();
      }

      for (final p in npcParsed) {
        final text = p.text.trim();
        if (text.isEmpty) continue;
        final isNarrator = isNarratorSpeaker(p.speaker);
        final displayName = isNarrator ? null : _fallbackSpeakerName(p.speaker);
        final key = isNarrator ? 'narrator' : 'unk:$displayName';
        if (key != currentKey) {
          flush();
          currentKey = key;
          currentDisplayName = displayName;
          currentIsNarrator = isNarrator;
        }
        lines.add(text);
      }
      flush();
    }
  } else {
    // Multi/single-NPC scenarios: group consecutive same-speaker runs and
    // resolve each run's mood/sprite the same way the scene always has.
    final seenCharacterIds = <String>{};
    String? currentKey;
    var currentIsNarrator = false;
    String? currentDisplayName;
    String? currentSpriteAsset;
    final lines = <String>[];

    void flush() {
      if (lines.isEmpty) return;
      final text = lines.join('\n');
      if (currentIsNarrator) {
        final narratorBeats = _splitNarratorBeats(text, config.npcCharacters);
        final distinctIds = narratorBeats.map((b) => b.$1.id).toSet();
        if (distinctIds.length > 1) {
          for (final (character, sentence) in narratorBeats) {
            beats.add(
              _Beat(
                kind: _BeatKind.narrator,
                text: sentence,
                characterId: character.id,
                spriteAsset: character.sprites.blink,
              ),
            );
          }
        } else {
          beats.add(_Beat(kind: _BeatKind.narrator, text: text));
        }
      } else {
        beats.add(
          _Beat(
            kind: _BeatKind.npc,
            text: text,
            characterId: currentKey,
            displayName: currentDisplayName,
            spriteAsset: currentSpriteAsset,
          ),
        );
      }
      lines.clear();
    }

    for (final p in npcParsed) {
      final text = p.text.trim();
      if (text.isEmpty) continue;

      final isNarrator = isNarratorSpeaker(p.speaker);
      final character = isNarrator
          ? null
          : resolveNpcCharacter(config, p.speaker ?? '');
      final displayName = isNarrator
          ? 'Narrator'
          : (character?.displayName ?? _fallbackSpeakerName(p.speaker));
      final key = isNarrator
          ? 'narrator'
          : (character?.id ?? 'unk:$displayName');

      String? spriteAsset;
      if (character != null) {
        final NpcMood mood;
        if (_lineIndicatesAngryMood(text) || npcMoodAngryThisTurn) {
          mood = NpcMood.frown;
        } else if (!seenCharacterIds.contains(character.id)) {
          mood = NpcMood.greet;
        } else if (text.endsWith('?')) {
          mood = NpcMood.tilt;
        } else {
          mood = NpcMood.blink;
        }
        seenCharacterIds.add(character.id);
        spriteAsset = character.sprites.forMood(mood);
      }

      if (key == currentKey) {
        lines.add(text);
      } else {
        flush();
        currentKey = key;
        currentIsNarrator = isNarrator;
        currentDisplayName = displayName;
        currentSpriteAsset = spriteAsset;
        lines.add(text);
      }
    }
    flush();
  }

  return beats;
}

// ── Scene ────────────────────────────────────────────────────────────────

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
  bool _echoVisible = false;

  // True once the player taps "Write your own response" on a multi-choice
  // turn — swaps the DraggableChoiceSheet for the medium-appropriate input
  // controls instead of only ever offering the backend's pre-written
  // options. Reset alongside the beat director on every new turn.
  bool _useCustomResponse = false;

  // Beat director — see _buildBeats/_onBeatDismissed.
  List<_Beat> _beats = const [];
  int _beatIndex = 0;
  String? _turnKey;
  bool _dialogueComplete = false;
  Timer? _advanceGapTimer;
  bool _transitionLocked = false;
  int _totalBeatsShown = 0;

  // Who's on stage in the NPC slot — survives across turns (Section 4.3):
  // the character stays put until a beat actually names someone new.
  String? _onStageCharacterId;
  String? _onStageSpriteAsset;

  bool _pickerOverrideOpen = false;
  String? _lastNpcLineForReplay;
  bool _replayOpen = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<ScenarioProvider>().config;
    if (config.npcCharacters.length == 1) {
      final ch = config.npcCharacters.first;
      _onStageCharacterId = ch.id;
      _onStageSpriteAsset = ch.sprites.blink;
    } else if (config.npcCharacters.isEmpty && config.spriteAsset != null) {
      _onStageCharacterId = _kFoaSupervisorImplicitId;
      _onStageSpriteAsset = config.spriteAsset;
    }
  }

  @override
  void dispose() {
    _advanceGapTimer?.cancel();
    _controller.dispose();
    _record.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await _record.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/themed_scenario_record.wav';

      // Ducked, not stopped — see TextResponseCard's identical call in
      // shared_widgets.dart for why (avoid an audible loop-restart gap).
      await HatiAudioService.instance.duckMusic();
      await _record.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: path,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() => _isRecording = true);
      }
    } else if (mounted) {
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
    HapticFeedback.lightImpact();
    final path = await _record.stop();
    await HatiAudioService.instance.restoreMusic();
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
      _echoVisible = true;
    });
  }

  void _sendText(ScenarioProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _lastSentText = text;
      _echoVisible = true;
    });
    provider.submitText(text);
  }

  Future<void> _handleMediumChosen(ResponseMedium medium) async {
    var finalMedium = medium;
    if (medium != ResponseMedium.type) {
      final granted = await _record.hasPermission();
      if (!mounted) return;
      if (!granted) {
        finalMedium = ResponseMedium.type;
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
    if (!mounted) return;
    context.read<ScenarioProvider>().setResponseMedium(finalMedium);
    setState(() => _pickerOverrideOpen = false);
  }

  void _syncOnStageForBeat(_Beat? beat) {
    if (beat == null) return;
    final isCharacterBeat =
        beat.kind == _BeatKind.npc ||
        (beat.kind == _BeatKind.narrator && beat.characterId != null);
    if (!isCharacterBeat) return;
    _onStageCharacterId = beat.characterId;
    _onStageSpriteAsset = beat.spriteAsset;
  }

  /// Single advance entry point for every beat kind — Hati's own bubble
  /// calls this via onSequenceComplete once it dissolves itself; the
  /// narrator/NPC bubble (HatiCoachSpeech) and plain caption (_TypedCaption)
  /// call it via onDismissed/onSequenceComplete too. Only one bubble is
  /// ever mounted at a time, so only one of them is ever listening to
  /// HatiDialogueTapController at once — the director itself never taps
  /// into that controller directly.
  void _onBeatDismissed() {
    if (!mounted || _transitionLocked) return;
    _transitionLocked = true;
    HapticFeedback.selectionClick();
    final isLast = _beatIndex + 1 >= _beats.length;
    _advanceGapTimer = Timer(Duration(milliseconds: isLast ? 150 : 120), () {
      if (!mounted) return;
      setState(() {
        _beatIndex++;
        _totalBeatsShown++;
        _syncOnStageForBeat(
          _beatIndex < _beats.length ? _beats[_beatIndex] : null,
        );
        if (_beatIndex >= _beats.length) _dialogueComplete = true;
        _transitionLocked = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final step = provider.backendStep;
    final config = provider.config;
    final activeSpriteAsset =
        (provider.npcMood == 'angry' && config.spriteAssetAngry != null)
        ? config.spriteAssetAngry
        : config.spriteAsset;
    final parsed = provider.messages.map(parseSpeakerMessage).toList();

    if (_onStageCharacterId == _kFoaSupervisorImplicitId) {
      _onStageSpriteAsset = activeSpriteAsset;
    }

    final turnKey = '$step:${provider.messages.join('|')}';
    if (turnKey != _turnKey) {
      _turnKey = turnKey;
      _advanceGapTimer?.cancel();
      _transitionLocked = false;
      _beatIndex = 0;
      _useCustomResponse = false;
      _replayOpen = false;
      _echoVisible = false;
      _beats = _buildBeats(
        config: config,
        parsed: parsed,
        activeSpriteAsset: activeSpriteAsset,
        npcMoodAngryThisTurn: provider.npcMood == 'angry',
      );
      _dialogueComplete = _beats.isEmpty;
      _syncOnStageForBeat(_beats.isNotEmpty ? _beats.first : null);
    }

    final pickerVisible =
        provider.responseMedium == null || _pickerOverrideOpen;
    final isTextInput = provider.ui.type == ScenarioUIType.textInput;
    final hasBackendCustomOption = provider.ui.options.any(
      (o) => o.toLowerCase().contains('custom'),
    );
    final isNumericScale = looksLikeNumericScale(provider.ui.options);
    final currentBeat = _beatIndex < _beats.length ? _beats[_beatIndex] : null;

    return Scaffold(
      backgroundColor: _kApproachBlue,
      body: HatiTapToAdvance(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SceneTopHeader(
                sceneLabel: 'The Approach',
                currentStep: 3,
                totalSteps: 7,
              ),
              const SceneSpeedToggleRow(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final stageW = c.maxWidth;
                    final stageH = c.maxHeight;
                    // Hati gets his own dedicated floor band at the bottom
                    // of the stage — background art is cropped to the
                    // space above it, so he stands on a clear, uncluttered
                    // strip of his own instead of sharing the scenic
                    // background with the NPC. This is what keeps the two
                    // from visually colliding: they occupy separate bands,
                    // not just separate corners of the same busy image.
                    final floorH = (stageH * 0.20).clamp(110.0, 160.0);
                    final backgroundH = stageH - floorH;
                    final hatiH = (floorH - 24).clamp(72.0, 120.0);
                    // The scenario's NPC art is a bust/portrait sprite (head
                    // + shoulders), not a full-body figure — sizing it off
                    // the full stage height blew it up into an oversized,
                    // badly cropped close-up that crowded into Hati's
                    // corner. Sized off the (now shorter) background band
                    // instead, and anchored above the floor band rather
                    // than at the very bottom, for clear separation.
                    final npcH = (backgroundH * 0.42).clamp(140.0, 210.0);
                    final npcBaseBottom = floorH + 20;

                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        // Layer 1: background art, cropped to the space
                        // above Hati's floor band (layer 1b below) rather
                        // than the full stage.
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: backgroundH,
                          child: Image.asset(
                            config.backgroundAsset,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: backgroundH,
                          ),
                        ),
                        // Layer 1b: Hati's floor — his own dedicated space,
                        // separate from the scenic background/NPC above it.
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: floorH,
                          child: const _HatiFloor(),
                        ),
                        // Layer 2: scrims for legibility only.
                        const IgnorePointer(child: _StageScrim()),
                        if (!pickerVisible) ...[
                          // Layer 3: NPC sprite, fixed bottom-right, resting
                          // just above Hati's floor band.
                          if (_onStageSpriteAsset != null)
                            Positioned(
                              right: 12,
                              bottom: npcBaseBottom,
                              child: _NpcStageSprite(
                                characterId: _onStageCharacterId,
                                spriteAsset: _onStageSpriteAsset,
                                height: npcH,
                              ),
                            ),
                          // Layer 4: Hati, fixed bottom-left within his own
                          // floor band, never moves.
                          Positioned(
                            left: 8,
                            bottom: 12,
                            child: currentBeat?.kind == _BeatKind.hati
                                ? HatiSpeakingBlock(
                                    key: ValueKey(_turnKey),
                                    persistentMessage: currentBeat!.text,
                                    frogSize: hatiH,
                                    mood: HatiMood.encourage,
                                    alignment: CrossAxisAlignment.start,
                                    dissolveBubble: true,
                                    autoAdvance: _kAutoAdvanceBeats,
                                    holdAfterTyping: const Duration(seconds: 3),
                                    showAdvanceCue: true,
                                    onSequenceComplete: _onBeatDismissed,
                                  )
                                : HatiFrogAvatar(
                                    size: hatiH,
                                    mood: HatiMood.idle,
                                  ),
                          ),
                          // Layer 5: the one active speech bubble/caption.
                          if (currentBeat != null &&
                              currentBeat.kind != _BeatKind.hati &&
                              !(currentBeat.kind == _BeatKind.narrator &&
                                  currentBeat.characterId == null))
                            _buildNpcOrNarratorBubble(
                              currentBeat,
                              stageW,
                              npcH,
                              npcBaseBottom,
                            ),
                          if (currentBeat != null &&
                              currentBeat.kind == _BeatKind.narrator &&
                              currentBeat.characterId == null)
                            Positioned(
                              top: 56,
                              left: 16,
                              right: 16,
                              child: Center(
                                child: _TypedCaption(
                                  key: ValueKey('${_turnKey}_$_beatIndex'),
                                  text: currentBeat.text,
                                  onDismissed: _onBeatDismissed,
                                ),
                              ),
                            ),
                          if (provider.isLoading &&
                              _lastSentText != null &&
                              _lastSentText!.isNotEmpty)
                            Positioned(
                              right: 24,
                              // Above the sprite's head (not partway down
                              // it) so the bubble/indicator never covers
                              // the NPC's face.
                              bottom: npcBaseBottom + npcH + 8,
                              child: const _TypingIndicator(),
                            ),
                          if (_replayOpen && _lastNpcLineForReplay != null)
                            Positioned(
                              right: 16,
                              bottom: npcBaseBottom + npcH + 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _replayOpen = false),
                                child: SizedBox(
                                  width: math.min(
                                    HatiLayout.bubbleMaxWidth,
                                    stageW - 32,
                                  ),
                                  child: _CharacterSpeechBubble(
                                    text: _lastNpcLineForReplay!,
                                  ),
                                ),
                              ),
                            ),
                          // Layer 8: player's echoed answer, frontmost.
                          Positioned(
                            left: hatiH + 24,
                            right: 16,
                            bottom: 16,
                            child: AnimatedOpacity(
                              opacity: _echoVisible ? 1 : 0,
                              duration: const Duration(milliseconds: 220),
                              child:
                                  (_lastSentText != null &&
                                      _lastSentText!.isNotEmpty)
                                  ? Align(
                                      alignment: Alignment.centerRight,
                                      child: _CharacterSpeechBubble(
                                        text: _lastSentText!,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          if (_dialogueComplete &&
                              !isTextInput &&
                              !_useCustomResponse &&
                              !isNumericScale &&
                              provider.ui.options.length > 1)
                            PopIn(
                              key: ValueKey(_turnKey),
                              child: DraggableChoiceSheet(
                                header: SectionHeader(
                                  title: 'Choose Your Response',
                                  subtitle: hasBackendCustomOption
                                      ? 'Select one'
                                      : 'Select one or write your own',
                                ),
                                body: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                    if (!hasBackendCustomOption)
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
                        // Layer 7: HUD. Progress now lives in the header
                        // band (SceneTopHeader) like every other scene —
                        // no floating pill duplicating it over the art.
                        if (!pickerVisible &&
                            _totalBeatsShown < 2 &&
                            currentBeat != null)
                          const Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(child: _TapAnywhereHint()),
                          ),
                        if (pickerVisible)
                          Positioned(
                            left: 8,
                            bottom: 12,
                            child: HatiSpeakingBlock(
                              persistentMessage:
                                  'How would you like to respond?',
                              frogSize: hatiH,
                              mood: HatiMood.thinking,
                              alignment: CrossAxisAlignment.start,
                              dissolveBubble: false,
                              autoAdvance: false,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (pickerVisible)
                _buildMediumPickerPanel(context)
              else
                _buildBottomSlot(
                  context,
                  provider,
                  isTextInput: isTextInput,
                  isNumericScale: isNumericScale,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNpcOrNarratorBubble(
    _Beat beat,
    double stageW,
    double npcH,
    double npcBaseBottom,
  ) {
    return Positioned(
      right: 16,
      bottom: npcBaseBottom + npcH + 8,
      child: SizedBox(
        width: math.min(HatiLayout.bubbleMaxWidth, stageW - 32),
        child: _NpcBubbleWithNameTag(
          nameLabel: beat.displayName,
          child: HatiCoachSpeech(
            key: ValueKey('${_turnKey}_$_beatIndex'),
            persistentMessage: beat.text,
            dissolveBubble: true,
            bubbleAlignment: Alignment.bottomRight,
            tailTargetX: HatiLayout.bubbleMaxWidth,
            textAlign: TextAlign.right,
            autoAdvance: _kAutoAdvanceBeats,
            showAdvanceCue: true,
            // NPC/narrator line, not Hati — no "Hati talk" voice cue here.
            playTalkSound: false,
            onBubbleDismissed: () {
              if (beat.kind == _BeatKind.npc) _lastNpcLineForReplay = beat.text;
            },
            onSequenceComplete: _onBeatDismissed,
          ),
        ),
      ),
    );
  }

  Widget _buildMediumPickerPanel(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: const Color(0xFFF5F1E8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How would you like to respond?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 14),
              _MediumTile(
                icon: Icons.mic_none_rounded,
                label: 'Voice',
                caption: 'Speak your answer',
                onTap: () => _handleMediumChosen(ResponseMedium.voice),
              ),
              const SizedBox(height: 10),
              _MediumTile(
                icon: Icons.keyboard_alt_outlined,
                label: 'Type',
                caption: 'Write your answer',
                onTap: () => _handleMediumChosen(ResponseMedium.type),
              ),
              const SizedBox(height: 10),
              _MediumTile(
                icon: Icons.forum_outlined,
                label: 'Both',
                caption: 'Speak or write',
                onTap: () => _handleMediumChosen(ResponseMedium.both),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSlot(
    BuildContext context,
    ScenarioProvider provider, {
    required bool isTextInput,
    required bool isNumericScale,
  }) {
    if (isTextInput || _useCustomResponse) {
      return _buildTextInputPanel(context, provider);
    }
    if (!_dialogueComplete) {
      return const SizedBox.shrink();
    }
    if (isNumericScale) {
      return PopIn(
        key: ValueKey(_turnKey),
        child: Container(
          color: const Color(0xFFF5F1E8),
          child: SafeArea(
            top: false,
            child: ScaleChoiceCard(
              options: provider.ui.options,
              isLoading: provider.isLoading,
              onSubmit: provider.submitText,
            ),
          ),
        ),
      );
    }
    if (provider.ui.options.length <= 1) {
      return PopIn(
        key: ValueKey(_turnKey),
        child: Container(
          color: const Color(0xFFF5F1E8),
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
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTextInputPanel(BuildContext context, ScenarioProvider provider) {
    final medium = provider.responseMedium ?? ResponseMedium.both;
    final panelHeight =
        (medium == ResponseMedium.voice ? 168.0 : 132.0) +
        MediaQuery.paddingOf(context).bottom;
    final showBackToChoices =
        _useCustomResponse && provider.ui.type != ScenarioUIType.textInput;

    return Container(
      height: panelHeight,
      decoration: const BoxDecoration(
        color: const Color(0xFFF5F1E8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Row(
                  children: [
                    if (showBackToChoices)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _useCustomResponse = false),
                        style: TextButton.styleFrom(
                          foregroundColor: _kApproachBlue,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back to choices'),
                      ),
                    const Spacer(),
                    if (_lastNpcLineForReplay != null)
                      Semantics(
                        button: true,
                        label: 'Replay what they said',
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _replayOpen = !_replayOpen),
                          style: TextButton.styleFrom(
                            foregroundColor: _kApproachBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'What did they say?',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    if (_dialogueComplete)
                      Semantics(
                        button: true,
                        label: 'Change how you respond',
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _pickerOverrideOpen = true),
                          style: TextButton.styleFrom(
                            foregroundColor: _kApproachBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Text(
                'What would you like to say?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Expanded(
                child: Center(
                  child: _dialogueComplete
                      ? PopIn(
                          key: ValueKey('${_turnKey}_$_beatIndex:input'),
                          child: _buildInputControls(context, provider, medium),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputControls(
    BuildContext context,
    ScenarioProvider provider,
    ResponseMedium medium,
  ) {
    if (medium == ResponseMedium.voice) {
      return _VoiceOnlyInputPanel(
        enabled: !provider.isLoading && !_isTranscribing,
        isRecording: _isRecording,
        isTranscribing: _isTranscribing,
        onMicTap: () =>
            _isRecording ? _stopRecording(provider) : _startRecording(),
      );
    }
    return _ApproachInputBar(
      controller: _controller,
      enabled: !provider.isLoading && !_isRecording && !_isTranscribing,
      isRecording: _isRecording,
      isTranscribing: _isTranscribing,
      showMic: medium == ResponseMedium.both,
      hintText: _isRecording
          ? 'Listening…'
          : (_isTranscribing
                ? 'Converting your voice…'
                : (provider.ui.placeholder?.isNotEmpty == true
                      ? provider.ui.placeholder!
                      : 'Type your response...')),
      onSend: () => _sendText(provider),
      onMicTap: () =>
          _isRecording ? _stopRecording(provider) : _startRecording(),
    );
  }
}

// ── Stage chrome ─────────────────────────────────────────────────────────

class _StageScrim extends StatelessWidget {
  const _StageScrim();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black26,
            Colors.transparent,
            Colors.transparent,
            Colors.black26,
          ],
          stops: [0, 0.22, 0.78, 1],
        ),
      ),
    );
  }
}

class _TapAnywhereHint extends StatelessWidget {
  const _TapAnywhereHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Tap anywhere to continue',
        style: TextStyle(color: const Color(0xFFF5F1E8), fontSize: 12),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1E8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_controller.value - i * 0.2) % 1.0;
              final phase = t < 0.5 ? t * 2 : (1 - t) * 2;
              final scale = 0.6 + 0.4 * phase.clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _kApproachBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ── Hati's floor ─────────────────────────────────────────────────────────

/// The dedicated strip at the stage's bottom edge that belongs to Hati
/// alone — a plain, uncluttered ground separate from the scenic background
/// (and the NPC standing on it), so he and the player's echoed answer
/// always have clear, unobstructed space instead of competing with the
/// background art and the NPC's portrait for the same corner.
class _HatiFloor extends StatelessWidget {
  const _HatiFloor();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kApproachBlue.withValues(alpha: 0.55),
            _kApproachBlue.withValues(alpha: 0.85),
          ],
        ),
      ),
    );
  }
}

// ── NPC on-stage sprite ──────────────────────────────────────────────────

/// One character at a time in the stage's NPC slot. A character-id change
/// fades+slides in the new sprite; a same-character mood change just
/// cross-fades. Static PNG sprites get a subtle idle breathing loop;
/// `.riv` sprites already animate on their own.
class _NpcStageSprite extends StatefulWidget {
  final String? characterId;
  final String? spriteAsset;
  final double height;

  const _NpcStageSprite({
    required this.characterId,
    required this.spriteAsset,
    required this.height,
  });

  @override
  State<_NpcStageSprite> createState() => _NpcStageSpriteState();
}

class _NpcStageSpriteState extends State<_NpcStageSprite> {
  bool _characterSwap = false;

  @override
  void didUpdateWidget(covariant _NpcStageSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    _characterSwap = oldWidget.characterId != widget.characterId;
  }

  @override
  Widget build(BuildContext context) {
    final sprite = widget.spriteAsset;
    if (sprite == null) return const SizedBox.shrink();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final key = ValueKey('${widget.characterId}::$sprite');
    final child = sprite.endsWith('.riv')
        ? NpcRiveSprite(key: key, assetPath: sprite, height: widget.height)
        : _BreathingSprite(key: key, assetPath: sprite, height: widget.height);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        if (reduceMotion || !_characterSwap) {
          return FadeTransition(opacity: animation, child: child);
        }
        final slide =
            Tween<Offset>(
              begin: const Offset(0.16, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: child,
    );
  }
}

class _BreathingSprite extends StatefulWidget {
  final String assetPath;
  final double height;

  const _BreathingSprite({
    super.key,
    required this.assetPath,
    required this.height,
  });

  @override
  State<_BreathingSprite> createState() => _BreathingSpriteState();
}

class _BreathingSpriteState extends State<_BreathingSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.assetPath,
      height: widget.height,
      fit: BoxFit.contain,
      alignment: Alignment.bottomRight,
    );
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return image;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + 0.015 * _controller.value,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: image,
    );
  }
}

// ── Narrator/NPC bubble chrome ───────────────────────────────────────────

class _NpcBubbleWithNameTag extends StatelessWidget {
  final String? nameLabel;
  final Widget child;

  const _NpcBubbleWithNameTag({this.nameLabel, required this.child});

  @override
  Widget build(BuildContext context) {
    if (nameLabel == null || nameLabel!.isEmpty) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4, right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _kApproachBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            nameLabel!,
            style: const TextStyle(
              color: const Color(0xFFF5F1E8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Plain narration with no character named — a distinct dark caption (no
/// tail), separate from the white speaker bubbles above. Runs its own
/// small typewriter/tap-advance loop rather than reusing the shared
/// speech-bubble painter, since that painter always draws a bubble+tail
/// shape unsuitable for a tailless caption.
class _TypedCaption extends StatefulWidget {
  final String text;
  final VoidCallback? onDismissed;

  const _TypedCaption({super.key, required this.text, this.onDismissed});

  @override
  State<_TypedCaption> createState() => _TypedCaptionState();
}

class _TypedCaptionState extends State<_TypedCaption> {
  int _visibleChars = 0;
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    HatiDialogueTapController.addListener(_handleTap);
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_visibleChars >= widget.text.length) return;
    _timer = Timer(HatiSpeechSpeedController.charInterval, () {
      if (!mounted) return;
      setState(() => _visibleChars++);
      _scheduleNext();
    });
  }

  void _handleTap() {
    if (!mounted || _dismissing) return;
    if (_visibleChars < widget.text.length) {
      _timer?.cancel();
      setState(() => _visibleChars = widget.text.length);
      return;
    }
    setState(() => _dismissing = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) widget.onDismissed?.call();
    });
  }

  @override
  void dispose() {
    HatiDialogueTapController.removeListener(_handleTap);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = widget.text.substring(
      0,
      _visibleChars.clamp(0, widget.text.length),
    );
    return AnimatedOpacity(
      opacity: _dismissing ? 0 : 1,
      duration: const Duration(milliseconds: 180),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * -12),
            child: child,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            displayed,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: const Color(0xFFF5F1E8),
              fontStyle: FontStyle.italic,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Character speech bubble (echoed answer / replay) ─────────────────────

class _CharacterSpeechBubble extends StatelessWidget {
  final String text;

  const _CharacterSpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.55,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1E8),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

// ── Medium picker tile ───────────────────────────────────────────────────

class _MediumTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  const _MediumTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  @override
  State<_MediumTile> createState() => _MediumTileState();
}

class _MediumTileState extends State<_MediumTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.label}: ${widget.caption}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _pressed
                ? _kApproachBlue.withValues(alpha: 0.12)
                : _kApproachBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _kApproachBlue.withValues(alpha: _pressed ? 0.6 : 0.3),
              width: _pressed ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kApproachBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: _kApproachBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _kApproachBlue,
                      ),
                    ),
                    Text(
                      widget.caption,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom input controls ────────────────────────────────────────────────

/// The "write your own" option at the end of the choice sheet's option
/// list — a lighter outlined style (pencil icon, no lettered badge) than
/// the [ScriptOptionCard]s above it.
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

class _VoiceOnlyInputPanel extends StatelessWidget {
  final bool enabled;
  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback onMicTap;

  const _VoiceOnlyInputPanel({
    required this.enabled,
    required this.isRecording,
    required this.isTranscribing,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isTranscribing
        ? 'Converting your voice…'
        : (isRecording ? 'Listening… tap to stop' : 'Tap to speak');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: isRecording ? 'Stop recording' : 'Start recording',
          child: GestureDetector(
            onTap: enabled ? onMicTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? Colors.red.withValues(alpha: 0.08)
                    : _kApproachBlue.withValues(alpha: 0.06),
                border: Border.all(
                  color: isRecording ? Colors.red : _kApproachBlue,
                  width: 3,
                ),
              ),
              child: Center(
                child: isTranscribing
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: _kApproachBlue,
                        ),
                      )
                    : Icon(
                        isRecording
                            ? Icons.stop_rounded
                            : Icons.graphic_eq_rounded,
                        size: 36,
                        color: isRecording ? Colors.red : _kApproachBlue,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
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

  /// False hides the mic icon/recording affordances entirely — used for
  /// [ResponseMedium.type], which never offers voice input.
  final bool showMic;

  const _ApproachInputBar({
    required this.controller,
    required this.enabled,
    required this.isRecording,
    this.isTranscribing = false,
    required this.hintText,
    required this.onSend,
    required this.onMicTap,
    this.showMic = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F1E8),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              if (showMic)
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
                      : IgnorePointer(
                          ignoring: isRecording,
                          child: Opacity(
                            opacity: isRecording ? 0.35 : 1.0,
                            child: Semantics(
                              button: true,
                              label: 'Record voice message',
                              child: IconButton(
                                icon: Icon(
                                  Icons.mic_none_rounded,
                                  color: enabled ? _kApproachBlue : Colors.grey,
                                  size: 28,
                                ),
                                onPressed: enabled ? onMicTap : null,
                              ),
                            ),
                          ),
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
              Semantics(
                button: true,
                label: showMic && isRecording ? 'Stop recording' : 'Send',
                child: IconButton(
                  icon: Icon(
                    showMic && isRecording
                        ? Icons.stop_circle_rounded
                        : Icons.send_rounded,
                    color: showMic && isRecording
                        ? Colors.red
                        : (enabled ? _kApproachBlue : Colors.grey),
                  ),
                  onPressed: showMic && isRecording
                      ? onMicTap
                      : (enabled ? onSend : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
