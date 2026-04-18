import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary orange palette (from design #f25c19)
  static const Color primary = Color(0xFFF25C19);
  static const Color primaryDark = Color(0xFFD94E12);
  static const Color primaryContent = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFFB923C);
  static const Color accent = Color(0xFFFDBA74);

  // Background
  static const Color backgroundLight = Color(0xFFEDE8D0);
  static const Color surface = Color(0xFFFFFFFF);

  // Text
  static const Color textMain = Color(0xFF0F172A);
  static const Color textSub = Color(0xFF475569);

  // Slate
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);

  // Green (for Start buttons)
  static const Color green600 = Color(0xFF16A34A);
  static const Color green700 = Color(0xFF15803D);
  static const Color green800 = Color(0xFF166534);

  // Orange accents
  static const Color orange100 = Color(0xFFFFEDD5);
  static const Color orange200 = Color(0xFFFED7AA);
  static const Color orange700 = Color(0xFFC2410C);
  static const Color orange900 = Color(0xFF7C2D12);

  // Blob colors
  static const Color blob1 = Color(0xFFFDBA74);
  static const Color blob2 = Color(0xFFFED7AA);
  static const Color blob3 = Color(0xFFFFEDD5);

  // Glass
  static const Color glassWhite = Color(0xA6FFFFFF); // rgba(255,255,255,0.65)
  static const Color glassBorder = Color(0x80FFFFFF); // rgba(255,255,255,0.5)

  // Keep these for backward compatibility
  static const Color sky100 = Color(0xFFE0F2FE);
  static const Color sky200 = Color(0xFFBAE6FD);
  static const Color sky800 = Color(0xFF075985);
  static const Color sky900 = Color(0xFF0C4A6E);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo200 = Color(0xFFC7D2FE);
  static const Color indigo700 = Color(0xFF4338CA);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald700 = Color(0xFF047857);
  static const Color sky500 = Color(0xFF0EA5E9);
  static const Color skyLight = Color(0xFFE0F2FE);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onSurface: AppColors.textMain,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      fontFamily: GoogleFonts.inter().fontFamily,
    );
  }
}
