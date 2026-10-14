// ─────────────────────────────────────────────
// HATI – Score animation sounds
// shared/audio/score_sounds.dart
//
// Ticks while a score gauge fills up, then one "reveal" once it lands —
// driven straight off the gauge's own animation, so the sounds always stay
// in sync with what's on screen (including the easing: ticks bunch up while
// the arc moves fast and spread out as it settles).
// ─────────────────────────────────────────────

import 'package:flutter/animation.dart';

import 'hati_audio_service.dart';

class ScoreAnimationSounds {
  /// Plays [ticks] evenly spaced ticks as [animation] goes from 0 to 1, then
  /// the reveal sound when it reaches 1. Call [dispose] with the screen.
  ScoreAnimationSounds(this.animation, {this.ticks = 8}) {
    animation.addListener(_onTick);
  }

  final Animation<double> animation;
  final int ticks;

  int _lastStep = 0;
  bool _revealed = false;

  void _onTick() {
    if (_revealed) return;
    final value = animation.value;
    if (value >= 1.0) {
      _revealed = true;
      HatiAudioService.instance.playScoreReveal();
      return;
    }
    final step = (value * ticks).floor();
    if (step > _lastStep) {
      _lastStep = step;
      HatiAudioService.instance.playScoreTick();
    }
  }

  void dispose() => animation.removeListener(_onTick);
}
