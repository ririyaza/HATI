import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Every spotlight target the dashboard tour can point to, created once by
/// [DashboardScreen] and handed down to each tab's screen (and the floating
/// help button) so their widgets can attach these keys.
class DashboardTourKeys {
  final navBarKey = GlobalKey();
  final helpButtonKey = GlobalKey();
  final homeChatKey = GlobalKey();
  final modulesGridKey = GlobalKey();
  final progressWeeklyKey = GlobalKey();
}

class _TourStep {
  const _TourStep({
    required this.title,
    required this.description,
    required this.icon,
    this.tabIndex,
    this.navIndex,
    this.keyOf,
  }) : assert(navIndex != null || keyOf != null);

  final String title;
  final String description;
  final IconData icon;

  /// Dashboard tab to switch to before this step is shown. Null leaves the
  /// current tab as-is (used for the help button, which floats above every
  /// tab).
  final int? tabIndex;

  /// When set, spotlights this segment of the bottom nav bar instead of a
  /// widget key.
  final int? navIndex;

  final GlobalKey Function(DashboardTourKeys keys)? keyOf;
}

const _kNavItemCount = 4;

final List<_TourStep> _tourSteps = [
  const _TourStep(
    title: 'Home',
    description: 'Come back here anytime for a quick check-in with Hati.',
    icon: Icons.home_rounded,
    tabIndex: 0,
    navIndex: 0,
  ),
  _TourStep(
    title: 'Ask Hati',
    description:
        "This is Hati, your AI assistant. Tap it to talk through how "
        "you're feeling, ask questions, or just check in — Hati replies in "
        'real time.',
    icon: Icons.chat_bubble_rounded,
    tabIndex: 0,
    keyOf: (k) => k.homeChatKey,
  ),
  const _TourStep(
    title: 'Modules',
    description: 'Practice social scenarios picked for your comfort profile.',
    icon: Icons.extension_rounded,
    tabIndex: 1,
    navIndex: 1,
  ),
  _TourStep(
    title: 'Ranked For You',
    description:
        'These modules are ranked using your SPIN assessment results — the '
        'higher the match %, the more that scenario targets the type of '
        'social anxiety you scored highest on.',
    icon: Icons.percent_rounded,
    tabIndex: 1,
    keyOf: (k) => k.modulesGridKey,
  ),
  const _TourStep(
    title: 'Progress',
    description: 'See your completed scenarios, daily streak, and badges.',
    icon: Icons.trending_up_rounded,
    tabIndex: 2,
    navIndex: 2,
  ),
  _TourStep(
    title: 'This Week',
    description:
        "Your day-by-day streak for the week, plus how far you've "
        "progressed through each scenario module you've started — tap for "
        'a detailed breakdown.',
    icon: Icons.calendar_today_rounded,
    tabIndex: 2,
    keyOf: (k) => k.progressWeeklyKey,
  ),
  const _TourStep(
    title: 'Profile',
    description: 'Manage your account, preferences, and settings.',
    icon: Icons.person_rounded,
    tabIndex: 3,
    navIndex: 3,
  ),
  _TourStep(
    title: 'Need Help?',
    description:
        'Tap this anytime to message the developer, reach mental-health '
        'support resources, or replay this tour.',
    icon: Icons.support_agent_rounded,
    keyOf: (k) => k.helpButtonKey,
  ),
];

/// Spotlight walkthrough of the dashboard's essentials — the bottom nav
/// bar, the Hati AI assistant, SPIN-ranked modules, weekly/module progress,
/// and the help button. Shown automatically once via [maybeShow] the first
/// time a user reaches [DashboardScreen], and re-triggerable anytime via
/// [show] (wired to the help button's "Replay Tutorial" entry).
class DashboardTourOverlay extends StatefulWidget {
  const DashboardTourOverlay({
    super.key,
    required this.keys,
    required this.onNavigate,
    required this.onDismiss,
  });

  final DashboardTourKeys keys;

  /// Switches the dashboard's visible tab so the step's target is on
  /// screen.
  final ValueChanged<int> onNavigate;
  final VoidCallback onDismiss;

  /// Inserts a [DashboardTourOverlay] into [context]'s [Overlay] if the
  /// current user hasn't completed (or skipped) it before. No-ops silently
  /// on any Firestore error so a network hiccup never blocks the dashboard.
  /// Returns whether the tour actually started, so callers that hide UI
  /// while it runs (e.g. the floating help button on the Profile tab) know
  /// when to restore it via [onDismiss].
  static Future<bool> maybeShow({
    required BuildContext context,
    required DashboardTourKeys keys,
    required ValueChanged<int> onNavigate,
    VoidCallback? onDismiss,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.data()?['dashboardTourCompleted'] == true) return false;
    } catch (_) {
      return false;
    }

    if (!context.mounted) return false;
    _insert(
      context: context,
      keys: keys,
      onNavigate: onNavigate,
      onDismiss: onDismiss,
    );
    return true;
  }

  /// Unconditionally (re)starts the tour from the beginning, regardless of
  /// whether it was already completed. Used by the help button's "Replay
  /// Tutorial" option.
  static void show({
    required BuildContext context,
    required DashboardTourKeys keys,
    required ValueChanged<int> onNavigate,
    VoidCallback? onDismiss,
  }) {
    onNavigate(0);
    _insert(
      context: context,
      keys: keys,
      onNavigate: onNavigate,
      onDismiss: onDismiss,
    );
  }

  static void _insert({
    required BuildContext context,
    required DashboardTourKeys keys,
    required ValueChanged<int> onNavigate,
    VoidCallback? onDismiss,
  }) {
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => DashboardTourOverlay(
        keys: keys,
        onNavigate: onNavigate,
        // Both the "target never appears" bailout and a normal finish can
        // each call onDismiss — guard against the second call hitting an
        // already-removed entry.
        onDismiss: () {
          if (entry.mounted) entry.remove();
          onDismiss?.call();
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  static Future<void> _markCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'dashboardTourCompleted': true,
        'dashboardTourCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  State<DashboardTourOverlay> createState() => _DashboardTourOverlayState();
}

class _DashboardTourOverlayState extends State<DashboardTourOverlay> {
  static const _maxRetries = 12;
  static const _retryDelay = Duration(milliseconds: 150);

  int _stepIndex = 0;
  int _retries = 0;
  bool _didAlignForStep = false;

  @override
  void initState() {
    super.initState();
    _prepareStep();
  }

  /// Scrolls the target into view when it lives inside a scrollable tab
  /// (Progress/Profile sections further down the page start off-screen).
  /// Runs once per step; jumps instantly and rebuilds once the scroll
  /// offset has actually applied.
  void _alignIfNeeded(_TourStep step) {
    if (_didAlignForStep || step.keyOf == null) return;
    final ctx = step.keyOf!(widget.keys).currentContext;
    if (ctx == null) return;
    _didAlignForStep = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: Duration.zero,
      ).then((_) {
        if (!mounted) return;
        // jumpTo only marks the viewport as needing layout — it isn't
        // flushed until the end of *this* next frame, so rebuilding
        // immediately would still measure the pre-scroll position. Wait one
        // more frame so the target's position has actually settled before
        // re-measuring it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      });
    });
  }

  /// Switches to the step's tab, if it needs one. Always deferred to a
  /// post-frame callback — this can run from [initState] (e.g. the very
  /// first step, mounted while the Overlay itself is still building), and
  /// calling `widget.onNavigate` synchronously there would call setState
  /// on DashboardScreen while an unrelated widget is mid-build, which
  /// Flutter rejects.
  void _prepareStep() {
    final tabIndex = _tourSteps[_stepIndex].tabIndex;
    if (tabIndex == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onNavigate(tabIndex);
    });
  }

  Rect? _targetRect(_TourStep step) {
    if (step.navIndex != null) {
      final box =
          widget.keys.navBarKey.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) return null;
      final origin = box.localToGlobal(Offset.zero);
      final segmentWidth = box.size.width / _kNavItemCount;
      return Rect.fromLTWH(
        origin.dx + segmentWidth * step.navIndex!,
        origin.dy,
        segmentWidth,
        box.size.height,
      );
    }

    final key = step.keyOf!(widget.keys);
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  Future<void> _finish() async {
    await DashboardTourOverlay._markCompleted();
    widget.onDismiss();
  }

  void _goTo(int index) {
    setState(() {
      _stepIndex = index;
      _retries = 0;
      _didAlignForStep = false;
    });
    _prepareStep();
  }

  void _next() {
    if (_stepIndex < _tourSteps.length - 1) {
      _goTo(_stepIndex + 1);
    } else {
      _finish();
    }
  }

  void _previous() {
    if (_stepIndex > 0) _goTo(_stepIndex - 1);
  }

  /// Called (via a post-frame callback) when the current step's target
  /// hasn't laid out yet — most often a Progress/Profile section still
  /// waiting on its Firestore stream. Retries for a few seconds, then
  /// gives up on this one step rather than leaving the tour stuck.
  void _scheduleRetry() {
    if (_retries >= _maxRetries) {
      if (_stepIndex < _tourSteps.length - 1) {
        _goTo(_stepIndex + 1);
      } else {
        widget.onDismiss();
      }
      return;
    }
    _retries++;
    Future.delayed(_retryDelay, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _tourSteps[_stepIndex];
    _alignIfNeeded(step);
    final rect = _targetRect(step);
    if (rect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleRetry();
      });
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.sizeOf(context);
    final isLast = _stepIndex == _tourSteps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Swallow taps so the dashboard behind isn't interactive
              // while the tour is up.
              onTap: () {},
              child: CustomPaint(
                painter: _SpotlightPainter(rect: rect),
                size: screenSize,
              ),
            ),
          ),
          _TourCard(
            targetRect: rect,
            screenSize: screenSize,
            step: step,
            stepIndex: _stepIndex,
            totalSteps: _tourSteps.length,
            isLast: isLast,
            onNext: _next,
            onPrevious: _stepIndex > 0 ? _previous : null,
            onSkip: _finish,
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.75);
    final hole = RRect.fromRectAndRadius(
      rect.inflate(6),
      const Radius.circular(18),
    );
    final scrimPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(scrimPath, scrim);
    canvas.drawRRect(
      hole,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.targetRect,
    required this.screenSize,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLast,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  final Rect targetRect;
  final Size screenSize;
  final _TourStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onSkip;

  static const _margin = 20.0;

  // Generous upper-bound estimate of the card's own height (icon row +
  // description + progress bar + buttons). A spotlight target could in
  // principle be taller than the screen; clamping against this keeps the
  // card (and its Next button) on screen instead of pushed off past the
  // bottom edge.
  static const _cardMinHeight = 260.0;
  static const _safeMargin = 20.0;

  @override
  Widget build(BuildContext context) {
    final screenH = screenSize.height;

    // The target itself may extend off-screen (e.g. a long scenario list);
    // clamp it to the visible area before using it to place the card.
    final target = Rect.fromLTRB(
      targetRect.left.clamp(0.0, screenSize.width),
      targetRect.top.clamp(0.0, screenH),
      targetRect.right.clamp(0.0, screenSize.width),
      targetRect.bottom.clamp(0.0, screenH),
    );

    // Anchor on whichever side of the (clamped) target has more room, then
    // clamp the result so the card always keeps its minimum height clear —
    // even if that means overlapping the spotlight a little.
    final spaceBelow = screenH - target.bottom;
    final spaceAbove = target.top;
    final anchorBelow = spaceBelow >= spaceAbove;
    final maxOffset = (screenH - _cardMinHeight - _safeMargin).clamp(
      0.0,
      screenH,
    );

    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B28D9).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(step.icon, color: const Color(0xFF0B28D9), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Step ${stepIndex + 1} of $totalSteps',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (stepIndex + 1) / totalSteps,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE0E0E0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0B28D9),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onPrevious != null)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0B28D9),
                    side: const BorderSide(color: Color(0xFF0B28D9)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: onPrevious,
                  child: const Text(
                    'Previous',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B28D9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: onNext,
                child: Text(
                  isLast ? 'Got it' : 'Next',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (anchorBelow) {
      return Positioned(
        left: _margin,
        right: _margin,
        top: (target.bottom + 14).clamp(0.0, maxOffset),
        child: card,
      );
    }
    return Positioned(
      left: _margin,
      right: _margin,
      bottom: (screenH - target.top + 14).clamp(0.0, maxOffset),
      child: card,
    );
  }
}
