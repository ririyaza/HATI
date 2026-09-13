// ─────────────────────────────────────────────
// HATI – Themed Scenario: entry widget
// scenario_play_page.dart
//
// Used by modules_screen.dart in place of the generic EmotionPage for
// every reachable scenario key. Wraps ScenarioShell in a
// ChangeNotifierProvider<ScenarioProvider>, kicking off `start()` with the
// same Firestore displayName lookup pattern EmotionPage uses
// (scenario_game.dart's `_loadUserDisplayNameFromFirestore`).
//
// Constructor params mirror EmotionPage's (`scenarioTitle`/`scenarioTheme`/
// `scenarioKey`) so call sites can swap the widget class without renaming
// arguments.
// ─────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'scenario_shell.dart';
import 'shared_widgets.dart';

class ScenarioPlayPage extends StatefulWidget {
  final String scenarioKey;
  final String scenarioTheme;
  final String scenarioTitle;

  const ScenarioPlayPage({
    super.key,
    required this.scenarioKey,
    required this.scenarioTheme,
    required this.scenarioTitle,
  });

  @override
  State<ScenarioPlayPage> createState() => _ScenarioPlayPageState();
}

class _ScenarioPlayPageState extends State<ScenarioPlayPage> {
  late final ScenarioProvider _provider;

  // True until the very first backend response actually arrives. Shown
  // instead of ScenarioShell (which otherwise renders Scene0PreSetup with
  // nothing but a bare spinner while this is in flight) — the backend
  // scales to zero when idle, so this first request can take up to a
  // minute on a cold start, and a bare spinner with no explanation reads
  // as "the app is broken" rather than "it's loading."
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    final config = scenarioConfigFor(
      widget.scenarioKey,
      theme: widget.scenarioTheme,
      title: widget.scenarioTitle,
    );
    _provider = ScenarioProvider(config: config);
    _bootstrap();
  }

  Future<String?> _loadUserDisplayNameFromFirestore(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final raw = doc.data()?['displayName'];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    } catch (_) {}

    final authName = user.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    String? displayName;
    if (user != null) {
      displayName = await _loadUserDisplayNameFromFirestore(user);
    }
    // start() catches its own errors (sets errorMessage, never throws), so
    // this always completes — on failure just as much as success — and
    // ScenarioShell's existing error snackbar takes over from here rather
    // than this loading screen getting stuck forever.
    await _provider.start(userId: user?.uid ?? '', userName: displayName);
    if (mounted) setState(() => _isBootstrapping = false);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScenarioProvider>.value(
      value: _provider,
      child: _isBootstrapping
          ? const _ScenarioLoadingScreen()
          : const ScenarioShell(),
    );
  }
}

/// Shown while the very first request to the backend is in flight — see
/// _isBootstrapping. Uses a time-based (not real-progress) bar: the backend
/// doesn't report how far along a cold start actually is, so this animates
/// toward ~92% over the typical worst-case cold-start window and just
/// holds there — never claims to be "done" — if the real response takes
/// longer than that, then snaps to 100% the instant the real response
/// actually arrives (jumping ahead of the simulated bar on a warm server,
/// where this whole screen is only visible for a fraction of a second).
class _ScenarioLoadingScreen extends StatefulWidget {
  const _ScenarioLoadingScreen();

  @override
  State<_ScenarioLoadingScreen> createState() => _ScenarioLoadingScreenState();
}

class _ScenarioLoadingScreenState extends State<_ScenarioLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  // Matches api/scenario_api.dart's own 60s request timeout — the bar
  // should finish approaching (not reach) 100% around when a cold start
  // realistically completes, not before.
  static const _simulatedDuration = Duration(seconds: 55);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _simulatedDuration)
      ..forward();
    // Fast at first (server likely already warm, most loads finish in this
    // window), then decelerating hard — Curves.easeOutExpo reaches ~92% by
    // the end rather than 100%, so it never visually lies about being done.
    _progress = Tween<double>(begin: 0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Same brand blue as Scene0's intro background, so there's no color
      // flash when this hands off to the real scenario content.
      backgroundColor: const Color(0xFF0B28D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HatiFrogAvatar(size: 160, mood: HatiMood.thinking),
              const SizedBox(height: 28),
              Text(
                'Getting things ready…',
                textAlign: TextAlign.center,
                style: HatiTextStyles.heading3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                "The server wakes up when it hasn't been used in a while — "
                "this can take up to a minute. Hang tight, no need to back "
                "out.",
                textAlign: TextAlign.center,
                style: HatiTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress.value,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
