// ─────────────────────────────────────────────
// HATI – App Theme & Design Tokens
// data/app_theme.dart
//
// Ported verbatim from testing_env/lib/app_theme.dart (moss/gold palette,
// text styles). No scenario logic lives here.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';

class HatiColors {
  // Brand palette
  static const Color deepForest = Color(0xFF1A2E1A);
  static const Color mossGreen = Color(0xFF2D5A27);
  static const Color leafGreen = Color(0xFF4CAF50);
  static const Color mintFresh = Color(0xFF80CBC4);
  static const Color warmCream = Color(0xFFF5F0E8);
  static const Color softGold = Color(0xFFD4A843);
  static const Color gentleAmber = Color(0xFFF59E0B);

  // Emotion colors
  static const Color anxious = Color(0xFFFF8A65);
  static const Color calm = Color(0xFF80CBC4);
  static const Color neutral = Color(0xFF90A4AE);
  static const Color scared = Color(0xFFCE93D8);
  static const Color angry = Color(0xFFEF5350);

  // UI
  static const Color surface = Color(0xFFF9F6F0);
  static const Color surfaceDark = Color(0xFF1C2B1C);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color dialogBg = Color(0xFFE8F5E9);
  static const Color hatiSpeech = Color(0xFFE8F5E9);
  static const Color professorSpeech = Color(0xFFF3E5F5);
  static const Color userSpeech = Color(0xFFE3F2FD);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMedium = Color(0xFF4A5568);
  static const Color textLight = Color(0xFF718096);
  static const Color divider = Color(0xFFE2E8F0);
}

class HatiTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: HatiColors.textDark,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: HatiColors.textDark,
    height: 1.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: HatiColors.textDark,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: HatiColors.textDark,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: HatiColors.textMedium,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: HatiColors.textLight,
    letterSpacing: 0.5,
  );

  static const TextStyle hatiSpeech = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: HatiColors.textDark,
    height: 1.6,
    fontStyle: FontStyle.italic,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: Colors.white,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}

class HatiTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: HatiColors.mossGreen,
      surface: HatiColors.surface,
        ),
        scaffoldBackgroundColor: HatiColors.surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: HatiColors.deepForest,
          foregroundColor: HatiColors.warmCream,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: HatiColors.warmCream,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: HatiColors.mossGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: HatiTextStyles.button,
            elevation: 2,
          ),
        ),
    cardTheme: CardThemeData(
          color: HatiColors.cardBg,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: HatiColors.mossGreen,
          thumbColor: HatiColors.leafGreen,
          overlayColor: HatiColors.mossGreen.withValues(alpha: 0.2),
          inactiveTrackColor: HatiColors.divider,
        ),
      );
}
