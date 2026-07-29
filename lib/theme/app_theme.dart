import 'package:flutter/material.dart';

/// Central neon / cyberpunk design language for Neon Drift Board.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg = Color(0xFF060512);
  static const Color bgDeep = Color(0xFF04030C);
  static const Color surface = Color(0xFF121128);
  static const Color surfaceHigh = Color(0xFF1B1A38);

  // Neon accents
  static const Color cyan = Color(0xFF00E5FF);
  static const Color blue = Color(0xFF3D8BFF);
  static const Color magenta = Color(0xFFFF2FB0);
  static const Color pink = Color(0xFFFF5DA2);
  static const Color purple = Color(0xFF9B5CFF);
  static const Color gold = Color(0xFFFFC53D);
  static const Color green = Color(0xFF2BE38B);
  static const Color danger = Color(0xFFFF4D6D);

  // Text
  static const Color textHigh = Color(0xFFF3F1FF);
  static const Color textMid = Color(0xFFAFA9D6);
  static const Color textLow = Color(0xFF6E688F);

  static const List<Color> primaryGradient = [cyan, purple];
  static const List<Color> magentaGradient = [magenta, purple];
  static const List<Color> goldGradient = [gold, Color(0xFFFF8A3D)];

  /// Rarity color mapping used across shop / garage / collections.
  static Color rarity(String r) {
    switch (r) {
      case 'common':
        return const Color(0xFF7DE2FF);
      case 'rare':
        return blue;
      case 'epic':
        return purple;
      case 'legendary':
        return gold;
      default:
        return textMid;
    }
  }
}

class AppText {
  AppText._();
  static const String display = 'Orbitron';
  static const String body = 'Rajdhani';
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan,
        secondary: AppColors.magenta,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.black,
        onSurface: AppColors.textHigh,
      ),
      textTheme: _textTheme(base.textTheme),
      splashColor: AppColors.cyan.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textHigh),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme t) {
    TextStyle disp(double size, [FontWeight w = FontWeight.w800]) => TextStyle(
          fontFamily: AppText.display,
          fontSize: size,
          fontWeight: w,
          color: AppColors.textHigh,
          letterSpacing: 1.0,
        );
    TextStyle body(double size, [FontWeight w = FontWeight.w500]) => TextStyle(
          fontFamily: AppText.body,
          fontSize: size,
          fontWeight: w,
          color: AppColors.textHigh,
          letterSpacing: 0.3,
        );
    return t.copyWith(
      displayLarge: disp(40, FontWeight.w900),
      displayMedium: disp(32, FontWeight.w800),
      headlineMedium: disp(24),
      headlineSmall: disp(20),
      titleLarge: disp(18, FontWeight.w700),
      titleMedium: body(18, FontWeight.w700),
      bodyLarge: body(17),
      bodyMedium: body(15),
      bodySmall: body(13, FontWeight.w400),
      labelLarge: body(15, FontWeight.w700),
    );
  }
}
