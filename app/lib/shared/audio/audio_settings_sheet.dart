// ─────────────────────────────────────────────
// HATI – Sound & Music settings sheet
// shared/audio/audio_settings_sheet.dart
//
// Opened from ProfileScreen's "Sound & Music" settings tile. Mirrors
// profile_screen.dart's own _NotificationSettingsSheet: a plain white
// modal bottom sheet with a title/subtitle and a couple of toggle rows,
// rather than a themed dialog — this is a utility settings panel, not
// scenario dialogue.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'hati_audio_service.dart';

const Color _kBlue = Color(0xFF0B28D9);

Future<void> showSoundSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFF5F1E8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _SoundSettingsSheet(),
  );
}

class _SoundSettingsSheet extends StatefulWidget {
  const _SoundSettingsSheet();

  @override
  State<_SoundSettingsSheet> createState() => _SoundSettingsSheetState();
}

class _SoundSettingsSheetState extends State<_SoundSettingsSheet> {
  final HatiAudioService _audio = HatiAudioService.instance;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _audio.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  Future<void> _setMusicEnabled(bool value) async {
    setState(() {}); // Reflect the tap immediately; awaited below settles it.
    await _audio.setMusicEnabled(value);
    if (mounted) setState(() {});
  }

  Future<void> _setSfxEnabled(bool value) async {
    await _audio.setSfxEnabled(value);
    if (mounted) setState(() {});
  }

  Future<void> _setMusicVolume(double value) async {
    await _audio.setMusicVolume(value);
    if (mounted) setState(() {});
  }

  Future<void> _setSfxVolume(double value) async {
    await _audio.setSfxVolume(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: _kBlue),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sound & Music',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Music pauses on its own while your voice is being recorded '
              'in a scenario.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _AudioToggleRow(
              label: 'Background music',
              description: 'Ambient music while you play through a scenario.',
              value: _audio.musicEnabled,
              onChanged: _setMusicEnabled,
            ),
            if (_audio.musicEnabled) ...[
              const SizedBox(height: 10),
              _VolumeSlider(
                value: _audio.musicVolume,
                onChanged: _setMusicVolume,
              ),
            ],
            const SizedBox(height: 14),
            _AudioToggleRow(
              label: 'Sound effects',
              description:
                  "Hati's voice cue, badge unlocks, and scene transitions.",
              value: _audio.sfxEnabled,
              onChanged: _setSfxEnabled,
            ),
            if (_audio.sfxEnabled) ...[
              const SizedBox(height: 10),
              _VolumeSlider(
                value: _audio.sfxVolume,
                onChanged: _setSfxVolume,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AudioToggleRow extends StatelessWidget {
  const _AudioToggleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: _kBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Plain 0–1 volume slider, deliberately with no numeric readout — the
/// setting that matters here is "how loud does this feel", not an exact
/// percentage.
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded, size: 18, color: Colors.black38),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: _kBlue,
                inactiveTrackColor: _kBlue.withValues(alpha: 0.15),
                thumbColor: _kBlue,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayColor: _kBlue.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: onChanged,
              ),
            ),
          ),
          const Icon(Icons.volume_up_rounded, size: 18, color: Colors.black38),
        ],
      ),
    );
  }
}
