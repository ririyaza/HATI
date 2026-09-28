import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../emotiondetection/themed_scenario/shared_widgets.dart'
    show HatiFrogAvatar, HatiMood;
import '../data/hati_chat_service.dart';

/// Free-form chat with Hati, entered from the homepage. Uses the same deep
/// blue gradient + soft blob texture as the app's other Hati-dialogue
/// screens (onboarding, post-assessment, spin-assessment), with frosted
/// glass message bubbles over it and Hati's own animated avatar pinned
/// above the conversation. This screen is otherwise unrelated to the
/// scenario/emotion-detection flow: no emotion logging, no scoring of any
/// kind. It does offer voice input, but only as a dictation shortcut —
/// recording is transcribed straight into the text box for the user to
/// review/edit, never auto-sent, unlike the scenario flow's voice input.
class HatiChatScreen extends StatefulWidget {
  const HatiChatScreen({super.key});

  @override
  State<HatiChatScreen> createState() => _HatiChatScreenState();
}

class _HatiChatScreenState extends State<HatiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatEntry>[];
  final _recorder = AudioRecorder();
  HatiChatService? _service;
  bool _sending = false;
  bool _isRecording = false;
  bool _isTranscribing = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _service = HatiChatService(uid: uid);
    }
    _messages.add(
      const _ChatEntry.hati(
        "Hi, I'm Hati. I'm here if you want to talk through anything "
        "that's on your mind, especially around social anxiety. What's "
        'going on?',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final service = _service;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You'll need to be signed in to use voice input.",
          ),
        ),
      );
      return;
    }

    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/hati_chat_record.wav';
      await _recorder.start(
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
            "right now — you can still type your message below. To use "
            "voice, allow microphone access for HATI in your device's "
            "Settings.",
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    HapticFeedback.lightImpact();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path == null) return;

    final service = _service;
    if (service == null) return;

    setState(() => _isTranscribing = true);
    try {
      final transcript = await service.transcribeAudio(path);
      if (!mounted) return;
      // Appended, not replaced — lets the user record a follow-up thought
      // onto text they already typed instead of losing it.
      final existing = _controller.text;
      final joined = existing.trim().isEmpty
          ? transcript
          : '$existing $transcript'.trim();
      _controller.value = TextEditingValue(
        text: joined,
        selection: TextSelection.collapsed(offset: joined.length),
      );
    } catch (e) {
      debugPrint('HatiChat transcription failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "I couldn't quite catch that — mind trying again, or typing "
              "instead?",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _send([String? retryText]) async {
    final text = retryText ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final service = _service;
    setState(() {
      if (retryText == null) {
        _messages.add(_ChatEntry.user(text));
        _controller.clear();
      }
      _sending = true;
    });
    _scrollToEnd();

    if (service == null) {
      setState(() {
        _sending = false;
        _messages.add(
          const _ChatEntry.error(
            "I couldn't start our chat — you'll need to be signed in for "
            'me to hear you.',
          ),
        );
      });
      return;
    }

    try {
      final reply = await service.send(text);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(_ChatEntry.hati(reply));
      });
    } catch (e, st) {
      debugPrint('HatiChat send failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(
          _ChatEntry.error(
            "Sorry, I couldn't quite catch that. Mind trying again?",
            retryText: text,
          ),
        );
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // Same gradient + soft blob texture as the onboarding/post-assessment
  // Hati-dialogue screens, so this chat reads as the same "world" as the
  // rest of the companion's dialogue rather than a plain utility screen.
  static const _bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B28D9), Color(0xFF14184F)],
  );

  static Widget _texturedBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(gradient: _bgGradient),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: _BackgroundBlob(size: 220, opacity: 0.14),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _BackgroundBlob(size: 260, opacity: 0.10),
          ),
          Positioned(
            top: 180,
            left: -30,
            child: _BackgroundBlob(size: 120, opacity: 0.08),
          ),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF14184F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: const Color(0xFFF5F1E8)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _texturedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight),
            child: Column(
              children: [
                _HatiHeader(thinking: _sending),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _MessageBubble(
                      entry: _messages[index],
                      onRetry: _send,
                    ),
                  ),
                ),
                if (_sending) const _TypingBubble(),
                _GlassInputBar(
                  controller: _controller,
                  sending: _sending,
                  isRecording: _isRecording,
                  isTranscribing: _isTranscribing,
                  onSend: () => _send(),
                  onMicTap: _toggleRecording,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hati's animated avatar + name, pinned above the conversation so the
/// companion feels present throughout the chat rather than only in the
/// opening message. Swaps to a "thinking" pose while a reply is in flight,
/// reusing the same mood-driven Rive avatar the scenario/dashboard scenes
/// use, instead of a second bespoke Hati illustration.
class _HatiHeader extends StatelessWidget {
  const _HatiHeader({required this.thinking});

  final bool thinking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          HatiFrogAvatar(
            size: 52,
            mood: thinking ? HatiMood.thinking : HatiMood.idle,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hati',
                style: TextStyle(
                  color: const Color(0xFFF5F1E8),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                thinking ? 'thinking...' : 'here to listen',
                style: TextStyle(color: Color(0xFFF5F1E8).withValues(alpha: 0.70), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ChatRole { user, hati, error }

class _ChatEntry {
  const _ChatEntry.user(this.text) : role = _ChatRole.user, retryText = null;
  const _ChatEntry.hati(this.text) : role = _ChatRole.hati, retryText = null;
  const _ChatEntry.error(this.text, {this.retryText}) : role = _ChatRole.error;

  final _ChatRole role;
  final String text;
  final String? retryText;
}

/// Frosted-glass panel: a blurred, translucent container with a thin light
/// border, so the gradient/blobs behind it stay visible through it instead
/// of a flat opaque card.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.tint = const Color(0xFFF5F1E8),
    this.fillOpacity = 0.16,
    this.borderColor,
    this.borderRadius = 18,
  });

  final Widget child;
  final Color tint;
  final double fillOpacity;
  final Color? borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: fillOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? const Color(0xFFF5F1E8).withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.entry, required this.onRetry});

  final _ChatEntry entry;
  final void Function(String) onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == _ChatRole.user;
    final isError = entry.role == _ChatRole.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _GlassPanel(
            fillOpacity: isUser ? 0.26 : (isError ? 0.18 : 0.16),
            tint: isUser
                ? const Color(0xFF4C6BFF)
                : (isError ? const Color(0xFFFF8A6B) : const Color(0xFFF5F1E8)),
            borderColor: isError
                ? const Color(0xFFFFB4A0).withValues(alpha: 0.6)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.text,
                    style: const TextStyle(
                      color: const Color(0xFFF5F1E8),
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                  if (isError && entry.retryText != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => onRetry(entry.retryText!),
                      child: const Text(
                        'Tap to retry',
                        style: TextStyle(
                          color: Color(0xFFFFD08A),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _GlassPanel(
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(),
                SizedBox(width: 4),
                _Dot(),
                SizedBox(width: 4),
                _Dot(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1E8).withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Frosted-glass input bar, floating over the textured background instead
/// of a flat opaque bar, to match the rest of the screen.
class _GlassInputBar extends StatelessWidget {
  const _GlassInputBar({
    required this.controller,
    required this.sending,
    required this.isRecording,
    required this.isTranscribing,
    required this.onSend,
    required this.onMicTap,
  });

  final TextEditingController controller;
  final bool sending;
  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback onSend;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    // Recording/transcribing disables typing and sending — same rule as
    // `sending` — so the transcript can't be edited or sent out from under
    // an in-flight recording.
    final locked = sending || isRecording || isTranscribing;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: _GlassPanel(
          borderRadius: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: isRecording ? 'Stop recording' : 'Record a message',
                  child: IconButton(
                    icon: isTranscribing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: const Color(0xFFF5F1E8),
                            ),
                          )
                        : Icon(
                            isRecording
                                ? Icons.stop_circle_rounded
                                : Icons.mic_none_rounded,
                            color: isRecording
                                ? const Color(0xFFFF8A6B)
                                : const Color(0xFFF5F1E8),
                          ),
                    onPressed: (sending || isTranscribing) ? null : onMicTap,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !locked,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: const Color(0xFFF5F1E8)),
                    cursorColor: const Color(0xFFF5F1E8),
                    decoration: InputDecoration(
                      hintText: isRecording
                          ? 'Listening...'
                          : (isTranscribing
                                ? 'Converting your voice...'
                                : 'Type a message...'),
                      hintStyle: TextStyle(
                        color: const Color(0xFFF5F1E8).withValues(alpha: 0.6),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: locked ? null : (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: const Color(0xFFF5F1E8),
                  onPressed: locked ? null : onSend,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundBlob extends StatelessWidget {
  const _BackgroundBlob({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFFF5F1E8).withValues(alpha: opacity),
              const Color(0xFFF5F1E8).withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
