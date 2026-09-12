import 'dart:async' as async;

import 'package:flutter/material.dart';

import '../../emotiondetection/themed_scenario/shared_widgets.dart'
    show HatiFrogAvatar, HatiSpeakingBlock, HatiTapToAdvance;

/// Hati's speech bubble outside the themed scenarios (dashboard, onboarding,
/// post-assessment, spin-assessment screens). Delegates the actual bubble +
/// typewriter to [HatiSpeakingBlock] — the same widget the scenarios use —
/// so the typing speed (incl. the global 2x toggle), sentence-by-sentence
/// pagination, tap-to-advance/dismiss, and bubble shape/animation all match
/// scenario dialogue instead of keeping a second, simpler implementation.
class HatiSpriteAnimation extends StatefulWidget {
  const HatiSpriteAnimation({
    super.key,
    this.size = 300,
    this.message =
        'Hello, I\'m Hati your virtual companion! How are you to see me?',
    this.startDelay = const Duration(seconds: 2),
    this.persistBubble = false,
    this.autoAdvance = false,
    this.holdAfterTyping = const Duration(seconds: 2),
    this.onDismissed,
    this.onTypingComplete,
  });

  final double size;
  final String message;
  final Duration startDelay;
  final bool persistBubble;

  /// When true, the bubble advances through the message and dismisses on
  /// its own after [holdAfterTyping] instead of waiting for a tap anywhere
  /// on screen — for companion-style dialogue that talks on its own.
  final bool autoAdvance;

  /// How long a fully-typed sentence stays up before [autoAdvance] moves on
  /// (to the next sentence, or dismisses on the last one).
  final Duration holdAfterTyping;

  /// Called once the bubble has fully dismissed (only reachable when
  /// [persistBubble] is false, since a persistent bubble never dismisses).
  final VoidCallback? onDismissed;

  /// Called once the message has fully finished typing out (its last
  /// sentence/page, specifically — not fired again per intermediate page).
  /// Reachable with [persistBubble] true or false. Use this to gate a
  /// screen's own Continue/action buttons until Hati is done talking,
  /// matching how scenario scenes gate their Continue/option buttons off
  /// [HatiCoachZone]'s `onSequenceComplete`.
  final VoidCallback? onTypingComplete;

  @override
  State<HatiSpriteAnimation> createState() => _HatiSpriteAnimationState();
}

class _HatiSpriteAnimationState extends State<HatiSpriteAnimation> {
  async.Timer? _startTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.startDelay == Duration.zero) {
      _started = true;
    } else {
      _startTimer = async.Timer(widget.startDelay, () {
        if (mounted) setState(() => _started = true);
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HatiTapToAdvance(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _started
            ? HatiSpeakingBlock(
                key: const ValueKey('hati-speaking'),
                persistentMessage: widget.message,
                frogSize: widget.size,
                dissolveBubble: !widget.persistBubble,
                autoAdvance: widget.autoAdvance,
                holdAfterTyping: widget.holdAfterTyping,
                onBubbleDismissed: widget.onDismissed,
                onSequenceComplete: widget.onTypingComplete,
              )
            : HatiFrogAvatar(
                key: const ValueKey('hati-waiting'),
                size: widget.size,
              ),
      ),
    );
  }
}
