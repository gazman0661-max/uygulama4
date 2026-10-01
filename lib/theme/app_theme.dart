import 'package:flutter/material.dart';

class AppColors {
  static const Color accentBlue = Color(0xFF29B6F6);
  static const Color accentCyan = Color(0xFF26C6DA);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentOrange = Color(0xFFFFB74D);
  static const Color accentPurple = Color(0xFF9575CD);
  static const Color accentGreenLink = Color(0xFF66BB6A);
  static const Color danger = Color(0xFFEF5350);

  static const Color lightBg = Color(0xFFEFF3F8);
  static const Color lightHeaderBg = Color(0xFFEFF3F8);
  static const Color lightBubbleBg = Color(0xFFFFFFFF);
  static const Color lightBubbleText = Color(0xFF3D8BB5);
  static const Color lightInputBg = Color(0xFFE3E8EF);
  static const Color lightIconChipBg = Color(0xFFE3E8EF);
  static const Color lightTitleText = Color(0xFF1A1A1A);

  static const Color darkBg = Color(0xFF0D1117);
  static const Color darkHeaderBg = Color(0xFF0D1117);
  static const Color darkBubbleBg = Color(0xFF161B22);
  static const Color darkBubbleText = Color(0xFF4FC3F7);
  static const Color darkInputBg = Color(0xFF161B22);
  static const Color darkIconChipBg = Color(0xFF161B22);
  static const Color darkTitleText = Color(0xFFFFFFFF);
}

class AppTheme {
  static const Color accentBlue = AppColors.accentBlue;
  static const Color accentCyan = AppColors.accentCyan;
  static const Color accentRed = AppColors.accentRed;
  static const Color accentOrange = AppColors.accentOrange;
  static const Color accentPurple = AppColors.accentPurple;
  static const Color accentGreenLink = AppColors.accentGreenLink;
  static const Color danger = AppColors.danger;

  static Widget noContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) =>
      const SizedBox.shrink();

  static ThemeData light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    fontFamily: 'monospace',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accentCyan,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    fontFamily: 'monospace',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accentCyan,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
