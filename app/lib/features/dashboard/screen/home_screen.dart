import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../emotiondetection/themed_scenario/shared_widgets.dart'
    show HatiFrogAvatar;
import '../../hatiChat/widgets/hati_chat_entry_bar.dart';
import '../../postAssessment/widgets/reassessment_banner.dart';
import '../widgets/hati_sprite_animation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.chatKey,
    this.hatiReady = false,
    this.hatiShowWelcome = false,
  });

  /// Spotlight target for the dashboard tour's "Ask Hati" step.
  final Key? chatKey;

  /// Set by [DashboardScreen] once it's safe for Hati to start talking —
  /// either the dashboard coach-mark tour has finished, or it was already
  /// completed in an earlier session. Kept false while the tour is running
  /// so Hati doesn't compete with it for attention.
  final bool hatiReady;

  /// Set alongside [hatiReady] when this is the first time [hatiReady]
  /// turns true because the user *just* finished the tour — Hati's first
  /// line is a welcome instead of a random tip.
  final bool hatiShowWelcome;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _welcomeMessage =
      "Welcome to HATI! I'm Hati, your companion for this journey. "
      "I'm really glad you're here — I'll be around whenever you need "
      'me, one step at a time.';

  static const _companionTips = <String>[
    "Small steps count. Even opening the app today is progress worth noticing.",
    'Feeling a little on edge? Try breathing in for 4 counts, and out for 6.',
    "You don't have to get social situations perfectly right — showing up is enough.",
    'The Modules tab has exercises ready whenever you want to practice something new.',
    "Curious how far you've come? Your Progress tab keeps track of it for you.",
    "It's okay to go at your own pace. There's no deadline on feeling better.",
    'A racing mind often slows down once you name what it is you\'re feeling.',
    "I'm just a tap away in the chat if you ever want to talk something through.",
    'Proud of you for checking in today — that matters more than it feels like.',
    'Anxiety can shrink a little just by putting it into words. Try it sometime.',
  ];

  static const _initialTipDelay = Duration(seconds: 4);
  static const _minIdleGap = Duration(seconds: 35);
  static const _maxIdleJitter = Duration(seconds: 55);
  static const _holdAfterTyping = Duration(seconds: 5);

  final _random = Random();

  Timer? _idleTimer;
  bool _started = false;
  int? _currentTipIndex;
  int _messageVersion = 0;

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hatiReady && !oldWidget.hatiReady) {
      _maybeStart();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _maybeStart() {
    if (_started || !widget.hatiReady) return;
    _started = true;
    if (widget.hatiShowWelcome) {
      setState(() {
        _currentTipIndex = null;
        _messageVersion++;
      });
    } else {
      _scheduleNextTip(initial: true);
    }
  }

  void _scheduleNextTip({bool initial = false}) {
    _idleTimer?.cancel();
    final delay = initial
        ? _initialTipDelay
        : _minIdleGap + Duration(seconds: _random.nextInt(_maxIdleJitter.inSeconds));
    _idleTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _currentTipIndex = _random.nextInt(_companionTips.length);
        _messageVersion++;
      });
    });
  }

  /// Fires once the current bubble (welcome or tip) has fully typed,
  /// auto-advanced through, and dissolved — chains into scheduling the next
  /// tip so Hati keeps checking back in on its own.
  void _onHatiDismissed() => _scheduleNextTip();

  String get _currentMessage =>
      _currentTipIndex == null
          ? _welcomeMessage
          : _companionTips[_currentTipIndex!];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/homepage_background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HATI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const ReassessmentBanner(),
              const Spacer(),
              Center(
                child: _started
                    ? HatiSpriteAnimation(
                        key: ValueKey(_messageVersion),
                        message: _currentMessage,
                        startDelay: Duration.zero,
                        autoAdvance: true,
                        holdAfterTyping: _holdAfterTyping,
                        onDismissed: _onHatiDismissed,
                      )
                    : const HatiFrogAvatar(size: 300),
              ),
              const Spacer(),
              HatiChatEntryBar(key: widget.chatKey),
            ],
          ),
        ),
      ),
    );
  }
}
