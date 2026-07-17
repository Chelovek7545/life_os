import 'package:flutter/material.dart';

class AppColors {
  // === БАЗОВЫЕ НЕЙТРАЛЬНЫЕ ЦВЕТА (ТЕМНАЯ ТЕМА) ===
  // Самый глубокий черный для заднего фона (Scaffold background)
  static const Color surfaceDim = Color(0xFF0C0B0B);
  // Базовый цвет поверхностей
  static const Color surface = Color(0xFF141212);
  // Чуть более яркая подложка
  static const Color surfaceBright = Color(0xFF1E1B1B);

  static const onBackground = Colors.white;
  // === ИЕРАРХИЯ КОНТЕЙНЕРОВ (От темного к светлому) ===
  // Нижний слой контейнеров (чуть светлее surface)
  static const Color surfaceContainerLowest = Color(0xFF101010);
  static const Color surfaceContainer = Color(0xFF1C1A1A);
  // Средний слой (карточки, инпуты)
  static const Color surfaceContainerLow = Color(0xFF151414);
  // Верхний слой (диалоги, всплывающие меню)
  static const Color surfaceContainerHigh = Color(0xFF312E2E);

  // === КОНТРАСТНЫЙ ТЕКСТ И ИКОНКИ ===
  // Главный текст (почти белый, мягкий для глаз)
  static const Color onSurface = Color(0xFFE5E2E1);
  // Второстепенный текст (подписи, даты)
  static const Color onSurfaceVariant = Color(0xFFE5BEB2);

  // === АКЦЕНТЫ (БРЕНД) ===
  // Основной оранжевый (пастельный для темной темы)
  static const Color primary = Color(0xFFFFB59C);
  // Фон для оранжевых кнопок/плашек. В M3 контейнеры в темной теме
  // обычно делают темнее, чтобы белый текст на них не слепил.
  // Если нужен именно ядовито-оранжевый, используй vibrantGradient.
  static const Color primaryContainer = Color(0xFFFF5C00);

  static const Color secondary = Color(0xFFDCB8FF);
  static const Color secondaryContainer = Color(0xFF550099);

  static const Color tertiary = Color(0xFFFFB1C3);

  // Эффекты свечения
  static const Color overdueGlow = Color(0x22FF5500);

  // === ГЛАССМОРФИЗМ (Альфа-каналы поверх surface) ===
  static final Color surfaceGlass = Colors.white.withOpacity(0.03);
  static final Color borderGlass = Colors.white.withOpacity(0.08);
  static final Color inputGlass = Colors.white.withOpacity(0.02);
  static final Color inputBorderGlass = Colors.white.withOpacity(0.1);

  // === ГРАДИЕНТЫ ===
  static const LinearGradient vibrantGradient = LinearGradient(
    colors: [Color(0xFFFF5500), Color(0xFF7701D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
