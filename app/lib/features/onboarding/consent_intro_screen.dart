import 'package:flutter/material.dart';

import '../dashboard/widgets/hati_sprite_animation.dart';
import 'consent_flow_screen.dart';
import 'data/consent_intro_hati_dialogue.dart';

class ConsentIntroScreen extends StatefulWidget {
  const ConsentIntroScreen({super.key});

  @override
  State<ConsentIntroScreen> createState() => _ConsentIntroScreenState();
}

class _ConsentIntroScreenState extends State<ConsentIntroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B28D9),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top label ──────────────────────────────────────
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'HATI',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Heading ────────────────────────────────────────
                  const Text(
                    'Before We Begin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We need your informed consent to include\nyour participation in our research study.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Hati sprite with speech bubble ────────────────
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft radial glow behind sprite
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.65,
                                colors: [
                                  Colors.white.withOpacity(0.07),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            HatiSpriteAnimation(
                              size: 220,
                              message: ConsentIntroHatiDialogue.message,
                              startDelay: Duration.zero,
                              persistBubble: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Steps preview chips ────────────────────────────
                  _StepsPreview(),

                  const SizedBox(height: 28),

                  // ── CTA button ─────────────────────────────────────
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0B28D9),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ConsentFlowScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Let\'s Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Steps preview ─────────────────────────────────────────────────────────────

class _StepsPreview extends StatelessWidget {
  const _StepsPreview();

  static const _steps = [
    'Study Info',
    'Data Use',
    'Risks',
    'Your Rights',
    'Confirm',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(
              width: 16,
              height: 1,
              color: Colors.white.withOpacity(0.25),
              margin: const EdgeInsets.symmetric(horizontal: 2),
            );
          }
          final idx = i ~/ 2;
          return _StepDot(number: idx + 1, label: _steps[idx]);
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  const _StepDot({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.18),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
