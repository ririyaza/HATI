import 'dart:async' as async;

import 'package:flame/components.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

class HatiSpriteAnimation extends StatefulWidget {
  const HatiSpriteAnimation({super.key, this.size = 300});

  final double size;

  @override
  State<HatiSpriteAnimation> createState() => _HatiSpriteAnimationState();
}

class _HatiSpriteAnimationState extends State<HatiSpriteAnimation> {
  static const _message = 'Hello, I\'m Hati! Welcome to my dashboard!';
  static final _frameSize = Vector2.all(512);

  async.Timer? _startTimer;
  async.Timer? _typingTimer;
  async.Timer? _hideTimer;
  bool _showTextbox = false;
  int _visibleCharacters = 0;

  @override
  void initState() {
    super.initState();
    _startTimer = async.Timer(const Duration(seconds: 2), _startTyping);
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
        _hideTimer = async.Timer(const Duration(seconds: 2), _hideTextbox);
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
    const textboxHeight = 50.0;
    const textboxGap = 10.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: textboxHeight,
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
        SpriteAnimationWidget.asset(
          path: 'HatiCharacter/frog_sprite_sheet.png',
          data: SpriteAnimationData.sequenced(
            amount: 10,
            amountPerRow: 10,
            stepTime: 0.055,
            textureSize: _frameSize,
          ),
          size: Size.square(widget.size),
          paint: Paint()
            ..isAntiAlias = true
            ..filterQuality = FilterQuality.high,
          loadingBuilder: (_) => SizedBox.square(dimension: widget.size),
        ),
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
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
