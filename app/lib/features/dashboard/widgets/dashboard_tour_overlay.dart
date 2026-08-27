import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class _TourStep {
  const _TourStep({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

const _tourSteps = [
  _TourStep(
    title: 'Home',
    description: 'Come back here anytime for a quick check-in with Hati.',
    icon: Icons.home_rounded,
  ),
  _TourStep(
    title: 'Modules',
    description: 'Practice social scenarios picked for your comfort profile.',
    icon: Icons.extension_rounded,
  ),
  _TourStep(
    title: 'Progress',
    description: 'See your completed scenarios, daily streak, and badges.',
    icon: Icons.trending_up_rounded,
  ),
  _TourStep(
    title: 'Profile',
    description: 'Manage your account, preferences, and settings.',
    icon: Icons.person_rounded,
  ),
];

/// Spotlight walkthrough of the dashboard's bottom navigation, shown once
/// via [maybeShow] the first time a user reaches [DashboardScreen].
class DashboardTourOverlay extends StatefulWidget {
  const DashboardTourOverlay({
    super.key,
    required this.navBarKey,
    required this.onDismiss,
  });

  /// Key on the [BottomNavigationBar] whose items this tour spotlights.
  final GlobalKey navBarKey;
  final VoidCallback onDismiss;

  /// Inserts a [DashboardTourOverlay] into [context]'s [Overlay] if the
  /// current user hasn't completed (or skipped) it before. No-ops silently
  /// on any Firestore error so a network hiccup never blocks the dashboard.
  static Future<void> maybeShow({
    required BuildContext context,
    required GlobalKey navBarKey,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.data()?['dashboardTourCompleted'] == true) return;
    } catch (_) {
      return;
    }

    if (!context.mounted) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => DashboardTourOverlay(
        navBarKey: navBarKey,
        // Both the "nav bar never laid out" bailout and a normal
        // Next/Skip finish can each call onDismiss — guard against the
        // second call hitting an already-removed entry.
        onDismiss: () {
          if (entry.mounted) entry.remove();
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
  int _stepIndex = 0;

  Rect? _targetRect() {
    final box =
        widget.navBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    final segmentWidth = box.size.width / _tourSteps.length;
    return Rect.fromLTWH(
      origin.dx + segmentWidth * _stepIndex,
      origin.dy,
      segmentWidth,
      box.size.height,
    );
  }

  Future<void> _finish() async {
    await DashboardTourOverlay._markCompleted();
    widget.onDismiss();
  }

  void _next() {
    if (_stepIndex < _tourSteps.length - 1) {
      setState(() => _stepIndex++);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect();
    if (rect == null) {
      // Nav bar isn't laid out (yet, or ever) — never leave an
      // unremovable scrim blocking the dashboard; just bail out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDismiss();
      });
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.sizeOf(context);
    final step = _tourSteps[_stepIndex];
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
    required this.onSkip,
  });

  final Rect targetRect;
  final Size screenSize;
  final _TourStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const _margin = 20.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _margin,
      right: _margin,
      bottom: screenSize.height - targetRect.top + 14,
      child: Container(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Row(
                  children: List.generate(
                    totalSteps,
                    (i) => Container(
                      margin: const EdgeInsets.only(right: 5),
                      width: i == stepIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == stepIndex
                            ? const Color(0xFF0B28D9)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
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
      ),
    );
  }
}
