import 'package:flutter/painting.dart';

/// The app's shared palette. Everything sits on the warm cream page color,
/// so surfaces, fills and borders are tints of that same cream rather than
/// pure white or cool grey/lavender, which look mismatched next to it.
abstract final class AppColors {
  /// Brand blue: headers, primary buttons, accents.
  static const blue = Color(0xFF0B28D9);

  /// Page background, and the text/icon color used on top of [blue].
  static const cream = Color(0xFFF5F1E8);

  /// Cards, inputs and panels sitting on [cream].
  static const creamSoft = Color(0xFFFBF8F1);

  /// Chips, icon wells and inactive fills — a step darker than [cream].
  static const creamDeep = Color(0xFFEAE4D5);

  /// Borders and dividers on [cream].
  static const creamLine = Color(0xFFDDD6C4);

  /// Selected / emphasized fill: [blue] at roughly 7% over [cream].
  static const blueTint = Color(0xFFE5E3EA);

  /// Primary dark text on [cream].
  static const ink = Color(0xFF1A1A2E);
}
