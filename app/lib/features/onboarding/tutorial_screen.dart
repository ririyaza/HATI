import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../dashboard/screen/dashboard_screen.dart';

// ──────────────────────────────────────────────
// Tutorial data model
// ──────────────────────────────────────────────

class _TutorialSlide {
  const _TutorialSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color accentColor;
}

const _slides = [
  _TutorialSlide(
    icon: Icons.waving_hand_rounded,
    title: 'Welcome to HATI',
    subtitle: 'Helping Anxiety Through Immersion',
    description:
        'HATI is your private, gamified companion designed to help you '
        'understand and manage social anxiety symptoms — at your own pace, '
        'anytime you need it.',
    accentColor: Color(0xFF5B8AF5),
  ),
  _TutorialSlide(
    icon: Icons.assignment_outlined,
    title: 'Your Profile',
    subtitle: 'Start with the SPIN Assessment',
    description:
        'Answer 17 quick questions so HATI can understand your anxiety '
        'triggers. Your profile is completely private and used only to '
        'personalise your experience.',
    accentColor: Color(0xFF7B61FF),
  ),
  _TutorialSlide(
    icon: Icons.extension_outlined,
    title: 'Scenario Modules',
    subtitle: 'Practice in a safe space',
    description:
        'Choose from social scenarios tailored to your profile — like finding '
        'a seat in a crowded room or talking to strangers. HATI guides you '
        'step by step and adapts to how you feel.',
    accentColor: Color(0xFF0BA2D9),
  ),
  _TutorialSlide(
    icon: Icons.mic_outlined,
    title: 'Emotion Detection',
    subtitle: 'HATI listens and understands',
    description:
        'Type or speak your responses. HATI analyses your text and optional '
        'voice input in real time to detect your emotional state and offer '
        'the right coping strategy at the right moment.',
    accentColor: Color(0xFF1DB95B),
  ),
  _TutorialSlide(
    icon: Icons.trending_up_rounded,
    title: 'Track Your Progress',
    subtitle: 'See yourself grow over time',
    description:
        'The Progress tab shows your completed scenarios, daily streak, '
        'emotion trends, and badges earned — giving you a clear picture of '
        'how far you\'ve come.',
    accentColor: Color(0xFFFF9500),
  ),
  _TutorialSlide(
    icon: Icons.favorite_outline_rounded,
    title: 'You\'re Not Alone',
    subtitle: 'HATI is a support tool, not a diagnosis',
    description:
        'HATI supplements — but does not replace — professional care. '
        'If you ever feel overwhelmed, the app will guide you to counselling '
        'resources. Your well-being always comes first.',
    accentColor: Color(0xFFFF6B6B),
  ),
];

// ──────────────────────────────────────────────
// Main Tutorial Screen (first-time only, after assessment complete)
// ──────────────────────────────────────────────

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _fadeController.reset();
    _fadeController.forward();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishTutorial();
    }
  }

  void _skipTutorial() => _finishTutorial();

  Future<void> _finishTutorial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'tutorialCompleted': true,
            'tutorialCompletedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0B28D9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HATI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: isLast ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: isLast ? null : _skipTutorial,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _TutorialSlideView(
                    slide: _slides[index],
                    fadeAnimation: _fadeAnimation,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: i == _currentPage
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _nextPage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isLast ? slide.accentColor : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isLast ? slide.accentColor : Colors.black)
                                .withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLast ? "Let's Get Started" : 'Next',
                            style: TextStyle(
                              color: isLast
                                  ? Colors.white
                                  : const Color(0xFF0B28D9),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLast
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                            color: isLast
                                ? Colors.white
                                : const Color(0xFF0B28D9),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialSlideView extends StatelessWidget {
  const _TutorialSlideView({
    required this.slide,
    required this.fadeAnimation,
  });

  final _TutorialSlide slide;
  final Animation<double> fadeAnimation;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slide.accentColor.withValues(alpha: 0.18),
                border: Border.all(
                  color: slide.accentColor.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  slide.icon,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: slide.accentColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: slide.accentColor.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              slide.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
