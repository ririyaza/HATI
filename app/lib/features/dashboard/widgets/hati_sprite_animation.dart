import 'dart:async' as async;
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

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
  static final _frameSize = Vector2.all(512);
  static const _idleSheet = 'HatiCharacter/frog_sprite_sheet.png';
  static const _blinkSheet = 'HatiCharacter/blinksheet.png';
  static const _idleFrameCount = 10;
  static const _blinkFrameCount = 15;
  static const _stepTime = 0.055;
  static const _blinkDuration = Duration(milliseconds: 825);

  async.Timer? _startTimer;
  async.Timer? _typingTimer;
  async.Timer? _hideTimer;
  async.Timer? _blinkTimer;
  async.Timer? _blinkResetTimer;
  final _random = math.Random();
  bool _showTextbox = false;
  bool _isBlinking = false;
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
    _scheduleBlink();
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _typingTimer?.cancel();
    _hideTimer?.cancel();
    _blinkTimer?.cancel();
    _blinkResetTimer?.cancel();
    super.dispose();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    final secondsUntilBlink = 2 + _random.nextInt(6);
    _blinkTimer = async.Timer(
      Duration(seconds: secondsUntilBlink),
      _startBlink,
    );
  }

  void _startBlink() {
    if (!mounted) return;

    setState(() => _isBlinking = true);

    _blinkResetTimer?.cancel();
    _blinkResetTimer = async.Timer(_blinkDuration, () {
      if (!mounted) return;
      setState(() => _isBlinking = false);
      _scheduleBlink();
    });
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
        SpriteAnimationWidget.asset(
          key: ValueKey(_isBlinking ? _blinkSheet : _idleSheet),
          path: _isBlinking ? _blinkSheet : _idleSheet,
          data: SpriteAnimationData.sequenced(
            amount: _isBlinking ? _blinkFrameCount : _idleFrameCount,
            amountPerRow: _isBlinking ? _blinkFrameCount : _idleFrameCount,
            stepTime: _stepTime,
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
