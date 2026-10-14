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
import 'package:flutter/widgets.dart';
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

class HatiAudioService with WidgetsBindingObserver {
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
  static const String _buttonAsset = 'SFX/button_sound.mp3';
  static const String _happyFrogAsset = 'SFX/happy_frog.wav';
  static const String _optionSelectAsset = 'SFX/option_select.mp3';
  static const String _completeScreenAsset = 'SFX/complete_screen.mp3';
  static const String _consentRecordedAsset = 'SFX/consent_recorded.mp3';
  static const String _scoreTickAsset = 'SFX/score_tick.mp3';
  static const String _scoreRevealAsset = 'SFX/score_reveal.mp3';
  static const String _typingAsset = 'SFX/typing_sound.wav';

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

  // False while the app is backgrounded/hidden. Dialogue typewriter timers
  // (e.g. the home screen's auto-advancing Hati bubbles) keep running in
  // the background, so without this gate Hati's talk cue kept croaking
  // after the user left the app.
  bool _appInForeground = true;
  // Set when a different track was requested while backgrounded, so the
  // return to foreground starts that track instead of resuming the old one.
  bool _trackChangedWhileHidden = false;

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

  DateTime? _lastButtonAt;
  // A double-tap or a tap that both pops a route and lands on the next
  // screen's button shouldn't stack two clicks on top of each other.
  static const _buttonThrottle = Duration(milliseconds: 80);
  // Button clicks sit under the other SFX — they fire constantly, so at the
  // full SFX volume they'd quickly get tiring.
  static const double _buttonVolumeFactor = 0.6;
  // Preloaded so a click lands on the tap itself — a fresh AudioPlayer per
  // click (like _playOneShot) has a noticeable load delay on Android. Same
  // for the other short sounds that fire in quick succession.
  Future<AudioPool?>? _buttonPool;
  Future<AudioPool?>? _optionPool;
  Future<AudioPool?>? _scoreTickPool;
  DateTime? _lastOptionAt;
  // Answer options and score ticks repeat quickly too — same reasoning as
  // the button click's lower volume.
  static const double _optionVolumeFactor = 0.6;
  static const double _scoreTickVolumeFactor = 0.5;

  // Dialogue typing loop: one dedicated player, started when a dialogue
  // section begins typing and stopped the moment its first line is done.
  // [_typingOwner] is whichever bubble started it, so a bubble finishing or
  // disposing never cuts off a newer bubble's typing.
  final AudioPlayer _typingPlayer = AudioPlayer();
  Object? _typingOwner;
  static const double _typingVolumeFactor = 0.5;

  DateTime? _lastHappyFrogAt;
  // Long enough that tapping Hati repeatedly, or a mood flip landing right
  // after a tap, doesn't turn into a continuous croak.
  static const _happyFrogThrottle = Duration(milliseconds: 1200);

  /// Loads persisted settings. Safe to call from multiple places (main(),
  /// the settings sheet, a scenario screen) — only the first call actually
  /// hits shared_preferences; the rest await that same in-flight load.
  Future<void> init() {
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    WidgetsBinding.instance.addObserver(this);
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
    // Warm the click pool in the background so the very first tap isn't
    // the one that pays the asset-load cost.
    _buttonPool ??= _createPool(_buttonAsset);
    _optionPool ??= _createPool(_optionSelectAsset);
    _scoreTickPool ??= _createPool(_scoreTickAsset);
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// Silences everything while the app isn't on screen: pauses the music
  /// (resumed on return if a screen still wants it) and blocks one-shot
  /// SFX such as Hati's talk cue.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _appInForeground) return;
    _appInForeground = foreground;
    if (!foreground) {
      _musicPlayer.pause().catchError((_) {});
      final typingOwner = _typingOwner;
      if (typingOwner != null) stopTyping(typingOwner);
      return;
    }
    final track = _currentTrack;
    final changed = _trackChangedWhileHidden;
    _trackChangedWhileHidden = false;
    if (!_musicWanted || !musicEnabled || track == null) return;
    if (changed) {
      playScenarioMusic(track: track);
    } else {
      _musicPlayer.resume().catchError((_) {});
    }
  }

  /// `ReleaseMode.loop` should already restart the track natively when it
  /// finishes — this listener is a safety net for the case where it
  /// somehow doesn't (an OS-level audio interruption — a phone call, a
  /// notification sound stealing focus despite [_kSharedAudioContext],
  /// etc.), so a scene never goes silent partway through just because one
  /// loop cycle didn't restart itself. Waits a beat first so it doesn't
  /// race the native loop's own restart on every ordinary cycle.
  Future<void> _onMusicPlayerComplete() async {
    if (!_musicWanted || !musicEnabled || !_appInForeground) return;
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
    if (!_appInForeground) {
      if (!sameTrack) _trackChangedWhileHidden = true;
      return;
    }
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
    if (!sfxEnabled || !_appInForeground) return;
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
      unawaited(Future.delayed(const Duration(seconds: 8), disposeOnce));

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

  /// Entering the scenario's Closing scene (step 6 of 7).
  Future<void> playCompleteScreen() => _playOneShot(_completeScreenAsset);

  /// The "Consent Recorded" dialog in the onboarding consent flow.
  Future<void> playConsentRecorded() => _playOneShot(_consentRecordedAsset);

  /// The SPIN result gauge landing on the final score.
  Future<void> playScoreReveal() => _playOneShot(_scoreRevealAsset);

  /// One step of the SPIN result gauge filling up (see score_sounds.dart).
  Future<void> playScoreTick() => _playFromPool(
    _scoreTickPool ??= _createPool(_scoreTickAsset),
    _scoreTickVolumeFactor,
  );

  /// Hati's happy croak — replaces [playHatiTalk] whenever Hati is in
  /// HatiMood.happy, and plays when the user taps Hati (see
  /// _HatiHappyVoice and HatiFrogAvatar in shared_widgets.dart).
  Future<void> playHappyFrog() async {
    final now = DateTime.now();
    final last = _lastHappyFrogAt;
    if (last != null && now.difference(last) < _happyFrogThrottle) return;
    _lastHappyFrogAt = now;
    await _playOneShot(_happyFrogAsset);
  }

  /// The tap click for buttons app-wide — fired by HatiTapSoundScope
  /// (shared/audio/hati_tap_sound.dart), not called per button.
  Future<void> playButton() async {
    final now = DateTime.now();
    final last = _lastButtonAt;
    if (last != null && now.difference(last) < _buttonThrottle) return;
    _lastButtonAt = now;
    await _playFromPool(
      _buttonPool ??= _createPool(_buttonAsset),
      _buttonVolumeFactor,
    );
  }

  /// Selecting an answer option / radio-style choice — fired by
  /// `HatiTapSound.option` markers, not called per option.
  Future<void> playOptionSelect() async {
    final now = DateTime.now();
    final last = _lastOptionAt;
    if (last != null && now.difference(last) < _buttonThrottle) return;
    _lastOptionAt = now;
    await _playFromPool(
      _optionPool ??= _createPool(_optionSelectAsset),
      _optionVolumeFactor,
    );
  }

  /// Starts the dialogue typing sound for [owner] (a speech bubble),
  /// looping until [stopTyping]. Called once per dialogue section, like
  /// [playHatiTalk], and stopped as soon as that section's first line has
  /// finished typing.
  Future<void> startTyping(Object owner) async {
    await _ensureInitialized();
    if (!sfxEnabled || !_appInForeground) return;
    _typingOwner = owner;
    try {
      await _typingPlayer.stop();
      await _typingPlayer.setReleaseMode(ReleaseMode.loop);
      await _typingPlayer.setVolume(sfxVolume * _typingVolumeFactor);
      // The line may already have finished typing (or a newer bubble taken
      // over) while the calls above were awaiting.
      if (_typingOwner != owner) return;
      await _typingPlayer.play(
        AssetSource(_typingAsset),
        ctx: _kSharedAudioContext,
      );
    } catch (e, st) {
      debugPrint('HatiAudioService.startTyping failed: $e\n$st');
    }
  }

  /// Stops the typing sound, but only if [owner] is the one playing it.
  Future<void> stopTyping(Object owner) async {
    if (_typingOwner != owner) return;
    _typingOwner = null;
    try {
      await _typingPlayer.stop();
    } catch (_) {}
  }

  Future<void> _playFromPool(
    Future<AudioPool?> pool,
    double volumeFactor,
  ) async {
    await _ensureInitialized();
    if (!sfxEnabled || !_appInForeground) return;
    try {
      final loaded = await pool;
      if (loaded == null) return;
      await loaded.start(volume: sfxVolume * volumeFactor);
    } catch (e, st) {
      debugPrint('HatiAudioService._playFromPool failed: $e\n$st');
    }
  }

  Future<AudioPool?> _createPool(String asset) async {
    try {
      return await AudioPool.create(
        source: AssetSource(asset),
        maxPlayers: 4,
        audioContext: _kSharedAudioContext,
      );
    } catch (e, st) {
      debugPrint('HatiAudioService: pool for $asset failed to load: $e\n$st');
      return null;
    }
  }

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
    } else if (_musicWanted && _appInForeground) {
      await playScenarioMusic(track: _currentTrack ?? HatiMusicTrack.scenario);
    }
  }

  Future<void> setSfxEnabled(bool value) async {
    await _ensureInitialized();
    sfxEnabled = value;
    final typingOwner = _typingOwner;
    if (!value && typingOwner != null) await stopTyping(typingOwner);
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
