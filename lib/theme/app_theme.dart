import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandOrange = Color(0xFFFF5800);
  static const Color brandCream = Color(0xFFEDE8D0);
  
  static const Color glassBackground = Color(0x66FFFFFF); // rgba(255, 255, 255, 0.4)
  static const Color glassBorder = Color(0x80FFFFFF);     // rgba(255, 255, 255, 0.5)

  static ThemeData get themeData {
    return ThemeData(
      scaffoldBackgroundColor: brandCream,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(seedColor: brandOrange),
      useMaterial3: true,
      textTheme: const TextTheme(
        // Add specific text styles if needed
      ),
    );
  }
}
