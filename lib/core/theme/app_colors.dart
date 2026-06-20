import 'package:flutter/material.dart';

class AppColors {
  // Базовые системные цвета
  static final Color scaffoldBackgroundColor = const Color(0xFF0E0E0E);
  //static const Color background = Color(0xFF050505);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);

  // Контрастные тексты
  static const Color onBackground = Color(0xFFE5E2E1);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE5BEB2);

  // Акценты (Бренд)
  static const Color primary = Color(0xFFFFB59C);
  static const Color primaryContainer = Color(0xFFFF5C00);
  
  static const Color secondary = Color(0xFFDCB8FF);
  static const Color secondaryContainer = Color(0xFF7701D0);
  static const Color tertiary = Color(0xFFFFB1C3); 
  static const Color overdueGlow = Color(0x33FF5500);

  // Глассморфизм (Альфа-каналы)
  static final Color surfaceGlass = Colors.white.withOpacity(0.03);
  static final Color borderGlass = Colors.white.withOpacity(0.08);
  static final Color inputGlass = Colors.white.withOpacity(0.02);
  static final Color inputBorderGlass = Colors.white.withOpacity(0.1);

  // Градиент для главных кнопок (Vibrant Gradient)
  static const LinearGradient vibrantGradient = LinearGradient(
    colors: [Color(0xFFFF5500), Color(0xFF7701D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}