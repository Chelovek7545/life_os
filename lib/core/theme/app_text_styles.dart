import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // Space Grotesk — Для крупных заголовков и цифр
  static TextStyle displayXL = GoogleFonts.spaceGrotesk(
    fontSize: 48,
    height: 1.1,
    letterSpacing: -0.02 * 48,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static TextStyle headlineLg = GoogleFonts.spaceGrotesk(
    fontSize: 32,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle headlineLgMobile = GoogleFonts.spaceGrotesk(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  // Inter — Для контента и описаний
  static TextStyle bodyMd = GoogleFonts.inter(
    fontSize: 16,
    height: 1.6,
    fontWeight: FontWeight.normal,
    color: AppColors.onBackground,
  );

  static TextStyle bodySm = GoogleFonts.inter(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.normal,
    color: AppColors.onSurfaceVariant,
  );

  // JetBrains Mono — Для системных меток, тегов и апперкейсов
  static TextStyle codeLabel = GoogleFonts.jetBrainsMono(
    fontSize: 12,
    height: 1.0,
    letterSpacing: 0.05 * 12,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurfaceVariant.withOpacity(0.6),
  );
}