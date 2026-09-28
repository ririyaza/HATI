// ─────────────────────────────────────────────
// HATI – Shared Audio Service
// shared/audio/hati_audio_service.dart
//
// Single app-wide place for background music + one-shot sound effects
// (assets/SFX/). Wraps `audioplayers` and persists the player's on/off +
// volume choices via shared_preferences, so the profile screen's "Sound &
// Music" settings sheet (see audio_settings_sheet.dart) and every scene
// that plays a sound read/write the exact same state.
//
// Music volume defaults low (20% here vs. dialogue's implied 100%) and SFX
// default a bit louder — matches the "keep music quiet, ~20-30% of
// dialogue's perceived loudness" guidance this was built against.
// ─────────────────────────────────────────────

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which looping background track should be playing. [scenario] covers
/// every scene except Scene 3 — office/P.I.E.S., preparation, debrief,
/// coping, closing, dashboard — and [interaction] is Scene 3's own track,
/// swapped in for just the NPC approach and back out once it ends.
enum HatiMusicTrack { scenario, interaction }

/// Applied to every player this service creates — music and one-shot SFX
/// alike. `audioplayers`' `AudioPlayer` defaults to
/// `AndroidAudioFocus.gain` on Android, meaning every new player (each SFX
/// one-shot included) requests *exclusive* audio focus by default; the OS
/// then pauses whichever player already held it, which is exactly why bg
/// music used to cut out the instant Hati's talk cue (or any other SFX)
/// played. `none` means none of our own players fight each other for
/// focus, so they mix freely — this app only ever plays its own sounds
/// simultaneously, never competes with another app's audio. `mixWithOthers`
/// on iOS is the equivalent: don't interrupt whatever else (e.g. the
/// user's own music app) might already be playing.
final AudioContext _kSharedAudioContext = AudioContext(
  android: const AudioContextAndroid(
    contentType: AndroidContentType.music,
    usageType: AndroidUsageType.media,
    audioFocus: AndroidAudioFocus.none,
  ),
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: const {AVAudioSessionOptions.mixWithOthers},
  ),
);

class HatiAudioService {
  HatiAudioService._();

  static final HatiAudioService instance = HatiAudioService._();

  static const _kMusicEnabledKey = 'hati_audio_music_enabled';
  static const _kSfxEnabledKey = 'hati_audio_sfx_enabled';
  static const _kMusicVolumeKey = 'hati_audio_music_volume';
  static const _kSfxVolumeKey = 'hati_audio_sfx_volume';

  static const double defaultMusicVolume = 0.22;
  static const double defaultSfxVolume = 0.85;

  // Music, once ducked (Scene 3 recording), drops to this fraction of
  // whatever the user's chosen music volume is — never silent, just far
  // enough under the mic to stop bleeding into a voice recording.
  static const double _duckFactor = 0.12;

  static const String _scenarioMusicAsset = 'SFX/preperation_bg.mp3';
  static const String _interactionMusicAsset = 'SFX/interaction_bg.mp3';
  static const String _hatiTalkAsset = 'SFX/hati_sound.mp3';
  static const String _badgeAsset = 'SFX/badge_completion.wav';
  static const String _scenarioCompleteAsset = 'SFX/scenario_complete.wav';
  static const String _sceneTransitionAsset = 'SFX/scene_transition.mp3';

  final AudioPlayer _musicPlayer = AudioPlayer();

  bool musicEnabled = true;
  bool sfxEnabled = true;
  double musicVolume = defaultMusicVolume;
  double sfxVolume = defaultSfxVolume;

  bool _initialized = false;
  Future<void>? _initFuture;

  // Whether whatever screen is currently active wants music running — set
  // by playScenarioMusic()/stopScenarioMusic() — so duckMusic()/
  // restoreMusic() (and re-enabling music mid-scenario) know whether there
  // is anything to actually (re)start.
  bool _musicWanted = false;
  bool _ducked = false;

  // Which track is currently selected (null = nothing started yet this
  // scenario). Tracked separately from whatever volume the player is
  // actually sitting at right now ([_lastSetMusicVolume]) so a repeated
  // playScenarioMusic() call for the *same* track — every scene change
  // re-asserts one — can no-op instead of restarting the loop audibly.
  HatiMusicTrack? _currentTrack;
  double _lastSetMusicVolume = 0;
  StreamSubscription<void>? _musicCompleteSub;

  DateTime? _lastHatiTalkAt;
  // Floor between consecutive "Hati talk" blips — sentences can be very
  // short, and without this a fast-typed run of one-word lines would fire
  // the sound almost continuously instead of once per line of dialogue.
  static const _hatiTalkThrottle = Duration(milliseconds: 260);

  /// Loads persisted settings. Safe to call from multiple places (main(),
  /// the settings sheet, a scenario screen) — only the first call actually
  /// hits shared_preferences; the rest await that same in-flight load.
  Future<void> init() {
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      musicEnabled = prefs.getBool(_kMusicEnabledKey) ?? true;
      sfxEnabled = prefs.getBool(_kSfxEnabledKey) ?? true;
      musicVolume = prefs.getDouble(_kMusicVolumeKey) ?? defaultMusicVolume;
      sfxVolume = prefs.getDouble(_kSfxVolumeKey) ?? defaultSfxVolume;
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      _musicCompleteSub = _musicPlayer.onPlayerComplete.listen(
        (_) => _onMusicPlayerComplete(),
      );
    } catch (e, st) {
      // Fall back to in-memory defaults above — a settings-read failure
      // shouldn't block audio from working for the rest of the session.
      debugPrint('HatiAudioService.init failed: $e\n$st');
    }
    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// `ReleaseMode.loop` should already restart the track natively when it
  /// finishes — this listener is a safety net for the case where it
  /// somehow doesn't (an OS-level audio interruption — a phone call, a
  /// notification sound stealing focus despite [_kSharedAudioContext],
  /// etc.), so a scene never goes silent partway through just because one
  /// loop cycle didn't restart itself. Waits a beat first so it doesn't
  /// race the native loop's own restart on every ordinary cycle.
  Future<void> _onMusicPlayerComplete() async {
    if (!_musicWanted || !musicEnabled) return;
    final track = _currentTrack;
    if (track == null) return;
    await Future.delayed(const Duration(milliseconds: 200));
    if (_musicPlayer.state == PlayerState.playing) return;
    try {
      await _musicPlayer.play(
        AssetSource(_assetForTrack(track)),
        ctx: _kSharedAudioContext,
      );
      await _setMusicPlayerVolume(
        _ducked ? musicVolume * _duckFactor : musicVolume,
      );
    } catch (e, st) {
      debugPrint('HatiAudioService._onMusicPlayerComplete failed: $e\n$st');
    }
  }

  // ── Background music ──────────────────────────────────────────────────

  String _assetForTrack(HatiMusicTrack track) => switch (track) {
    HatiMusicTrack.scenario => _scenarioMusicAsset,
    HatiMusicTrack.interaction => _interactionMusicAsset,
  };

  /// Sets the music player's volume and remembers it, so [_fadeMusicVolume]
  /// has a real starting point to ramp from without needing to read it back
  /// from the player (audioplayers doesn't expose a reliable synchronous
  /// getter for it).
  Future<void> _setMusicPlayerVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _lastSetMusicVolume = clamped;
    await _musicPlayer.setVolume(clamped);
  }

  /// Linearly ramps the music player's volume from wherever it currently
  /// is to [to] over [duration], in a handful of steps — a scene/track
  /// change should cross-fade, not hard-cut. Best-effort: a failure
  /// mid-ramp just stops stepping rather than throwing.
  Future<void> _fadeMusicVolume(double to, Duration duration) async {
    const steps = 8;
    final from = _lastSetMusicVolume;
    final target = to.clamp(0.0, 1.0);
    final stepDelay = Duration(
      milliseconds: (duration.inMilliseconds / steps).round(),
    );
    for (var i = 1; i <= steps; i++) {
      final value = from + (target - from) * (i / steps);
      try {
        await _setMusicPlayerVolume(value);
      } catch (_) {
        return;
      }
      if (i < steps) await Future.delayed(stepDelay);
    }
  }

  /// Starts (or resumes) the scenario's looping background music on
  /// [track], short-fading out whatever was already playing first if
  /// [track] differs from what's currently selected — see [HatiMusicTrack].
  /// Safe to call repeatedly with the same track (every scene change
  /// re-asserts one; this no-ops rather than audibly restarting the loop),
  /// and safe to call even while `musicEnabled` is off — it just remembers
  /// which track is "wanted" so flipping the setting back on resumes it.
  Future<void> playScenarioMusic({
    HatiMusicTrack track = HatiMusicTrack.scenario,
  }) async {
    await _ensureInitialized();
    _musicWanted = true;
    final sameTrack = _currentTrack == track;
    _currentTrack = track;
    if (!musicEnabled) return;
    if (sameTrack && _musicPlayer.state == PlayerState.playing) return;

    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      if (!sameTrack && _musicPlayer.state == PlayerState.playing) {
        await _fadeMusicVolume(0, const Duration(milliseconds: 400));
        await _musicPlayer.stop();
      }
      await _setMusicPlayerVolume(0);
      await _musicPlayer.play(
        AssetSource(_assetForTrack(track)),
        ctx: _kSharedAudioContext,
      );
      final target = _ducked ? musicVolume * _duckFactor : musicVolume;
      await _fadeMusicVolume(target, const Duration(milliseconds: 500));
    } catch (e, st) {
      // Missing/corrupt asset or no audio output on this device — music is
      // a nice-to-have, never worth crashing a scenario over. Logged (not
      // silently swallowed) so a real problem is at least visible in the
      // debug console instead of just "no sound, no clue why".
      debugPrint('HatiAudioService.playScenarioMusic($track) failed: $e\n$st');
    }
  }

  /// Stops the scenario's background music entirely — call when leaving
  /// the scenario flow, not for a momentary pause (see [duckMusic]).
  Future<void> stopScenarioMusic() async {
    _musicWanted = false;
    _ducked = false;
    _currentTrack = null;
    _lastSetMusicVolume = 0;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  /// Temporarily lowers music under the mic while Scene 3 (or any other
  /// voice-recording input) is capturing the player's voice, so the
  /// background track doesn't bleed into the recording or the speech
  /// pipeline. Pair with [restoreMusic] once recording stops. Instant, not
  /// faded — recording can start on short notice and shouldn't wait on a
  /// ramp.
  Future<void> duckMusic() async {
    if (_ducked || !_musicWanted) return;
    _ducked = true;
    try {
      await _setMusicPlayerVolume(musicVolume * _duckFactor);
    } catch (_) {}
  }

  /// Undoes [duckMusic] once recording has stopped.
  Future<void> restoreMusic() async {
    if (!_ducked) return;
    _ducked = false;
    try {
      await _setMusicPlayerVolume(musicVolume);
    } catch (_) {}
  }

  // ── One-shot sound effects ────────────────────────────────────────────

  Future<void> _playOneShot(String asset) async {
    await _ensureInitialized();
    if (!sfxEnabled) return;
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(sfxVolume);

      // Dispose once playback actually finishes, or after a flat timeout as
      // a safety net if the completion event never fires — whichever comes
      // first. Deliberately not `Future.timeout()`: audioplayers' actual
      // runtime stream type there didn't line up with its declared
      // `Stream<void>` signature, so an `onTimeout` closure returning null
      // threw a TypeError *before* play() ever ran, silently killing every
      // one-shot sound. Two independent futures racing via whichever
      // resolves first sidesteps that entirely.
      var disposed = false;
      void disposeOnce() {
        if (disposed) return;
        disposed = true;
        player.dispose();
      }

      unawaited(player.onPlayerComplete.first.then((_) => disposeOnce()));
      unawaited(
        Future.delayed(const Duration(seconds: 8), disposeOnce),
      );

      await player.play(AssetSource(asset), ctx: _kSharedAudioContext);
    } catch (e, st) {
      // Same reasoning as playScenarioMusic(): never let a missing sound
      // asset or a busy audio session interrupt the scenario itself.
      debugPrint('HatiAudioService._playOneShot($asset) failed: $e\n$st');
    }
  }

  /// A short blip played once per section of Hati's dialogue — the whole
  /// message, however many sentence-bubbles it paginates into as the
  /// player taps through — not once per bubble/sentence (see
  /// _AnimatedHatiSpeechBubbleState._typeCurrentSentence's `_sentenceIndex
  /// == 0` gate in shared_widgets.dart) and never for NPC/narrator lines,
  /// which reuse the same typewriter widget but pass `playTalkSound:
  /// false`. The throttle below is just a safety net against two sections
  /// starting back-to-back in the same frame.
  Future<void> playHatiTalk() async {
    final now = DateTime.now();
    final last = _lastHatiTalkAt;
    if (last != null && now.difference(last) < _hatiTalkThrottle) return;
    _lastHatiTalkAt = now;
    await _playOneShot(_hatiTalkAsset);
  }

  Future<void> playBadgeCompletion() => _playOneShot(_badgeAsset);

  Future<void> playScenarioComplete() => _playOneShot(_scenarioCompleteAsset);

  Future<void> playSceneTransition() => _playOneShot(_sceneTransitionAsset);

  // ── Settings (read by audio_settings_sheet.dart) ──────────────────────

  Future<void> setMusicEnabled(bool value) async {
    await _ensureInitialized();
    musicEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMusicEnabledKey, value);
    } catch (_) {}
    if (!value) {
      try {
        await _musicPlayer.stop();
      } catch (_) {}
    } else if (_musicWanted) {
      await playScenarioMusic(track: _currentTrack ?? HatiMusicTrack.scenario);
    }
  }

  Future<void> setSfxEnabled(bool value) async {
    await _ensureInitialized();
    sfxEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSfxEnabledKey, value);
    } catch (_) {}
  }

  Future<void> setMusicVolume(double value) async {
    await _ensureInitialized();
    musicVolume = value.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kMusicVolumeKey, musicVolume);
    } catch (_) {}
    if (!_ducked) {
      try {
        await _setMusicPlayerVolume(musicVolume);
      } catch (_) {}
    }
  }

  Future<void> setSfxVolume(double value) async {
    await _ensureInitialized();
    sfxVolume = value.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kSfxVolumeKey, sfxVolume);
    } catch (_) {}
  }
}
