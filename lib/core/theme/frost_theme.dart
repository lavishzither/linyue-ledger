import 'package:flutter/material.dart';

/// 清冷像素风色板（设计书 §3.2）
class FrostColors {
  static const bgBase = Color(0xFFE8EEF4);
  static const bgPanel = Color(0xFFF7FAFC);
  static const bgMistEnd = Color(0xFFEDE4EC);
  static const border = Color(0xFF9AA8B8);
  static const text = Color(0xFF2C3A4A);
  static const textDim = Color(0xFF6B7C8F);
  static const accentIce = Color(0xFF7EB6D4);
  static const accentViolet = Color(0xFF8B7BA8);
  static const accentRose = Color(0xFFC4899A);
  static const expense = Color(0xFFB85C6E);
  static const income = Color(0xFF5A9A8A);
  static const balance = Color(0xFF4A6B8A);
  static const barEmpty = Color(0xFFD0D8E2);
  static const barFill = Color(0xFF7EB6D4);
  static const warning = Color(0xFFA67C52);

  static const piePalette = <Color>[
    Color(0xFF7EB6D4),
    Color(0xFF8B7BA8),
    Color(0xFFC4899A),
    Color(0xFF5A9A8A),
    Color(0xFF6B8CAE),
    Color(0xFFA89BB8),
    Color(0xFF9BB8C4),
    Color(0xFFB89A8A),
    Color(0xFF7A9B8C),
    Color(0xFF9AADC4),
    Color(0xFFB8A0B0),
    Color(0xFF8AA8B8),
  ];
}

class FrostTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.light(
        primary: FrostColors.accentIce,
        secondary: FrostColors.accentViolet,
        error: FrostColors.expense,
        surface: FrostColors.bgPanel,
        onPrimary: Colors.white,
        onSurface: FrostColors.text,
      ),
      scaffoldBackgroundColor: FrostColors.bgBase,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: FrostColors.text,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: FrostColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      dividerColor: FrostColors.border,
    );
    return base;
  }
}
