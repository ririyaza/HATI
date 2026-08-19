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
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

const _kApproachBlue = Color(0xFF4A8FD4);
const _kApproachCyan = Color(0xFF00D4FF);
const _kFrogSize = 100.0;

class Scene3Interaction extends StatefulWidget {
  const Scene3Interaction({super.key});

  @override
  State<Scene3Interaction> createState() => _Scene3InteractionState();
}

class _Scene3InteractionState extends State<Scene3Interaction> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _record = AudioRecorder();
  bool _isRecording = false;
  String? _lastSentText;

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
    if (mounted) setState(() => _isRecording = false);
    if (path == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    await provider.submitAudio(path, userId: userId);
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
    if (step == 'foa_s3_reaction' && uiType == ScenarioUIType.textInput) return 0.55;
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

    final parsed = provider.messages.map(parseSpeakerMessage).toList();
    final profLines = parsed
        .where((p) => (p.speaker ?? '').toLowerCase() != 'hati')
        .map((p) => p.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    final hatiLines = parsed
        .where((p) => (p.speaker ?? '').toLowerCase() == 'hati')
        .map((p) => p.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();

    final profText = profLines.isNotEmpty ? profLines.join('\n\n') : 'Yes? What is it?';
    final hatiText = hatiLines.join('\n\n');
    final isTextInput = provider.ui.type == ScenarioUIType.textInput;

    return Scaffold(
      backgroundColor: _kApproachBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ApproachTopBar(progress: _progressForStep(step, provider.ui.type)),
            Expanded(
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
                  Positioned(
                    right: 4,
                    top: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _CharacterSpeechBubble(text: profText),
                        if (config.spriteAsset != null) ...[
                          const SizedBox(height: 8),
                          Image.asset(
                            config.spriteAsset!,
                            height: sceneHeight * 0.34,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_lastSentText != null && _lastSentText!.isNotEmpty)
                    Positioned(
                      left: 16,
                      top: 100,
                      child: _CharacterSpeechBubble(
                        text: _lastSentText!,
                        alignEnd: false,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ApproachHatiLane(
                      showBubble: hatiText.isNotEmpty,
                      message: hatiText,
                      bubbleKey: '$step:$hatiText',
                      frogSize: _kFrogSize,
                    ),
                  ),
                ],
              ),
            ),
            if (isTextInput)
              _ApproachInputBar(
                controller: _controller,
                enabled: !provider.isLoading && !_isRecording,
                isRecording: _isRecording,
                hintText: _isRecording ? 'Listening…' : 'Type your response...',
                onSend: () => _sendText(provider),
                onMicTap: () =>
                    _isRecording ? _stopRecording(provider) : _startRecording(),
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

  const _ApproachHatiLane({
    required this.showBubble,
    required this.message,
    required this.bubbleKey,
    this.frogSize = 100,
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
          SizedBox(
            width: frogSize + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBubble && message.isNotEmpty)
                  HatiSpeakingBlock(
                    key: ValueKey(bubbleKey),
                    persistentMessage: message,
                    frogSize: frogSize,
                  )
                else
                  HatiFrogAvatar(size: frogSize),
              ],
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

// ── Character speech bubble (prof / user) ─────────────────────────────────────

class _CharacterSpeechBubble extends StatelessWidget {
  final String text;
  final bool alignEnd;

  const _CharacterSpeechBubble({
    required this.text,
    this.alignEnd = true,
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
        child: Text(
          text,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
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

// ── Bottom input bar ──────────────────────────────────────────────────────────

class _ApproachInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isRecording;
  final String hintText;
  final VoidCallback onSend;
  final VoidCallback onMicTap;

  const _ApproachInputBar({
    required this.controller,
    required this.enabled,
    required this.isRecording,
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
          IconButton(
            icon: Icon(
              isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
              color: isRecording
                  ? Colors.red
                  : (enabled ? _kApproachBlue : Colors.grey),
              size: 28,
            ),
            onPressed: (enabled || isRecording) ? onMicTap : null,
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
