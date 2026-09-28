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

  static const String _bgMusicAsset = 'SFX/bg_music.mp3';
  static const String _hatiTalkAsset = 'SFX/hati_sound.mp3';
  static const String _badgeAsset = 'SFX/badge_completion.wav';
  static const String _scenarioCompleteAsset = 'SFX/scenario_complete.wav';
  static const String _sceneTransitionAsset = 'SFX/scene_transition.wav';

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

  // ── Background music ──────────────────────────────────────────────────

  /// Starts (or resumes) the scenario's looping background music. Safe to
  /// call even while `musicEnabled` is off — it just remembers that music
  /// is "wanted" so flipping the setting back on mid-scenario resumes it.
  Future<void> playScenarioMusic() async {
    await _ensureInitialized();
    _musicWanted = true;
    if (!musicEnabled) return;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_ducked ? musicVolume * _duckFactor : musicVolume);
      await _musicPlayer.play(AssetSource(_bgMusicAsset));
    } catch (e, st) {
      // Missing/corrupt asset or no audio output on this device — music is
      // a nice-to-have, never worth crashing a scenario over. Logged (not
      // silently swallowed) so a real problem is at least visible in the
      // debug console instead of just "no sound, no clue why".
      debugPrint('HatiAudioService.playScenarioMusic failed: $e\n$st');
    }
  }

  /// Stops the scenario's background music entirely — call when leaving
  /// the scenario flow, not for a momentary pause (see [duckMusic]).
  Future<void> stopScenarioMusic() async {
    _musicWanted = false;
    _ducked = false;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  /// Temporarily lowers music under the mic while Scene 3 (or any other
  /// voice-recording input) is capturing the player's voice, so the
  /// background track doesn't bleed into the recording or the speech
  /// pipeline. Pair with [restoreMusic] once recording stops.
  Future<void> duckMusic() async {
    if (_ducked || !_musicWanted) return;
    _ducked = true;
    try {
      await _musicPlayer.setVolume(musicVolume * _duckFactor);
    } catch (_) {}
  }

  /// Undoes [duckMusic] once recording has stopped.
  Future<void> restoreMusic() async {
    if (!_ducked) return;
    _ducked = false;
    try {
      await _musicPlayer.setVolume(musicVolume);
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
      unawaited(
        player.onPlayerComplete.first
            .timeout(const Duration(seconds: 8), onTimeout: () {})
            .whenComplete(player.dispose),
      );
      await player.play(AssetSource(asset));
    } catch (e, st) {
      // Same reasoning as playScenarioMusic(): never let a missing sound
      // asset or a busy audio session interrupt the scenario itself.
      debugPrint('HatiAudioService._playOneShot($asset) failed: $e\n$st');
    }
  }

  /// A short blip played once per line of Hati's dialogue as it types out
  /// — never per character (see the throttle above), and never for NPC/
  /// narrator lines, which reuse the same typewriter widget but pass
  /// `playTalkSound: false`.
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
      await playScenarioMusic();
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
        await _musicPlayer.setVolume(musicVolume);
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
