import 'package:flutter/material.dart';

import 'consent_flow_screen.dart';

class ConsentIntroScreen extends StatelessWidget {
  const ConsentIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B2CFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
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
                'Continue',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Before We Begin',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: _SpeechBubble(
                  text:
                      'Before using HATI, we need your permission to include '
                      'your participation in a research study. This will take '
                      'about 2-3 minutes.',
                ),
              ),
              Center(
                child: Image.asset(
                  'assets/bouncehati2.png',
                  width: 300,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B2CFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Positioned(
          bottom: -10,
          right: 30,
          child: Transform.rotate(
            angle: 0.35,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFF0B2CFF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                  topLeft: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
