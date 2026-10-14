import 'dart:async' as async;

import 'package:flutter/material.dart';

import '../../emotiondetection/themed_scenario/shared_widgets.dart'
    show HatiFrogAvatar, HatiMood, HatiSpeakingBlock, HatiTapToAdvance;

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
    this.bubbleGap = 8,
    this.mood = HatiMood.idle,
    this.showAdvanceCue,
  });

  final double size;
  final String message;
  final Duration startDelay;
  final bool persistBubble;

  /// Forwarded to [HatiSpeakingBlock.bubbleGap] — see its doc comment.
  /// Defaults to the same 8 [HatiSpeakingBlock] itself defaults to, so
  /// existing callers are unaffected.
  final double bubbleGap;

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

  /// Hati's expression. [HatiMood.happy] also swaps Hati's talk sound for
  /// the happy croak — for good-news screens only (e.g. improved
  /// post-assessment results), never the worsened/referral/low-score ones.
  final HatiMood mood;

  /// Overrides whether the pulsing "tap to continue" chevron shows once a
  /// line finishes typing. Left null (the default), it falls back to
  /// `!autoAdvance` — auto-advancing dialogue doesn't need the cue since it
  /// moves on by itself. Pass true to show it anyway, as a reminder that
  /// tapping (anywhere on screen, via HatiTapToAdvance below) still skips
  /// ahead of the auto-advance timer for anyone who doesn't want to wait.
  final bool? showAdvanceCue;

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
                mood: widget.mood,
                bubbleGap: widget.bubbleGap,
                dissolveBubble: !widget.persistBubble,
                autoAdvance: widget.autoAdvance,
                holdAfterTyping: widget.holdAfterTyping,
                onBubbleDismissed: widget.onDismissed,
                onSequenceComplete: widget.onTypingComplete,
                // Auto-advancing dialogue doesn't need a "tap to continue"
                // prompt — it moves on by itself. Tap-paced dialogue does.
                // (widget.showAdvanceCue overrides this when explicitly set.)
                showAdvanceCue: widget.showAdvanceCue ?? !widget.autoAdvance,
              )
            : HatiFrogAvatar(
                key: const ValueKey('hati-waiting'),
                size: widget.size,
                mood: widget.mood,
              ),
      ),
    );
  }
}
