import 'dart:async' as async;

import 'package:flutter/material.dart';

import '../../emotiondetection/themed_scenario/shared_widgets.dart'
    show HatiFrogAvatar, HatiMood;

class HatiSpriteAnimation extends StatefulWidget {
  const HatiSpriteAnimation({
    super.key,
    this.size = 300,
    this.message =
        'Hello, I\'m Hati your virtual companion! How are you to see me?',
    this.startDelay = const Duration(seconds: 2),
    this.persistBubble = false,
  });

  final double size;
  final String message;
  final Duration startDelay;
  final bool persistBubble;

  @override
  State<HatiSpriteAnimation> createState() => _HatiSpriteAnimationState();
}

class _HatiSpriteAnimationState extends State<HatiSpriteAnimation> {
  late final String _message;

  async.Timer? _startTimer;
  async.Timer? _typingTimer;
  async.Timer? _hideTimer;
  bool _showTextbox = false;
  int _visibleCharacters = 0;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    if (widget.startDelay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTyping());
    } else {
      _startTimer = async.Timer(widget.startDelay, _startTyping);
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _typingTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    if (!mounted) return;

    setState(() {
      _showTextbox = true;
      _visibleCharacters = 0;
    });

    _typingTimer = async.Timer.periodic(const Duration(milliseconds: 90), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_visibleCharacters >= _message.length) {
        timer.cancel();
        _typingTimer = null;
        if (!widget.persistBubble) {
          _hideTimer = async.Timer(const Duration(seconds: 2), _hideTextbox);
        }
        return;
      }

      setState(() {
        _visibleCharacters++;
      });
    });
  }

  void _hideTextbox() {
    if (!mounted) return;

    setState(() {
      _showTextbox = false;
      _visibleCharacters = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    const textboxGap = 10.0;
    final bubbleMaxHeight = (widget.size * 0.55).clamp(72.0, 120.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: bubbleMaxHeight,
            maxHeight: bubbleMaxHeight,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showTextbox
                  ? _HatiTextbox(
                      key: const ValueKey('hati-textbox'),
                      text: _message.substring(0, _visibleCharacters),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty-textbox')),
            ),
          ),
        ),
        const SizedBox(height: textboxGap),
        HatiFrogAvatar(size: widget.size, mood: HatiMood.idle),
      ],
    );
  }
}

class _HatiTextbox extends StatelessWidget {
  const _HatiTextbox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF0B28D9),
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}
