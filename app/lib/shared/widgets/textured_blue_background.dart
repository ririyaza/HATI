import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The blue gradient with soft cream glows used on the onboarding-style
/// screens (consent intro, assessment complete, low-score exit).
class TexturedBlueBackground extends StatelessWidget {
  const TexturedBlueBackground({super.key, required this.child});

  final Widget child;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.blue, Color(0xFF14184F)],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _gradient),
      child: Stack(
        children: [
          const Positioned(
            top: -60,
            right: -40,
            child: _Blob(size: 220, opacity: 0.14),
          ),
          const Positioned(
            bottom: -80,
            left: -60,
            child: _Blob(size: 260, opacity: 0.10),
          ),
          const Positioned(
            top: 180,
            left: -30,
            child: _Blob(size: 120, opacity: 0.08),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.cream.withValues(alpha: opacity),
              AppColors.cream.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
