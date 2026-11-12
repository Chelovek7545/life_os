import 'dart:io';

import 'package:flutter/material.dart';
import 'package:graph_components/graph_components.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'app_colors.dart';



const _white = Color(0xFFFAFAFA);   // zinc-50
const _dark = Color(0xFF18181B);    // zinc-900
const _muted = Color(0xFFA1A1AA);   // zinc-400
const _track = Color(0xFF27272A);   // zinc-800
const _border = Color(0x1FFFFFFF);  // white 12%
const _fill = Color(0x0FFFFFFF);    // white 6%  — "стекло"
const _popover = Color(0xF218181B); // zinc-900 95%

final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
final _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(10),
  borderSide: const BorderSide(color: _border),
);
const _btnText = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
const _btnPad = EdgeInsets.symmetric(horizontal: 16);

final shadGlassTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,

  // Палитра shadcn (zinc)
  colorScheme: const ColorScheme.dark(
    primary: _white,
    onPrimary: _dark,
    secondary: _track,
    onSecondary: _white,
    surface: Color(0xFF09090B),
    onSurface: _white,
    onSurfaceVariant: _muted,
    outline: _border,
    error: Color(0xFFEF4444),
    onError: _white,
  ),
  scaffoldBackgroundColor: const Color(0xFF0A0A10),
  splashColor: Colors.white10,
  highlightColor: Colors.white10,

  // AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    foregroundColor: _white,
    titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _white),
  ),

  // Cards — стеклянные: полупрозрачные + граница
  cardTheme: CardThemeData(
    color: _fill,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: _border),
    ),
  ),

  // Slider
  sliderTheme: const SliderThemeData(
    trackHeight: 6,
    activeTrackColor: _white,
    inactiveTrackColor: _track,
    thumbColor: _white,
    overlayColor: _border,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
    trackShape: RoundedRectSliderTrackShape(),
    valueIndicatorColor: _white,
    valueIndicatorTextStyle: TextStyle(color: _dark, fontSize: 12, fontWeight: FontWeight.w600),
    showValueIndicator: ShowValueIndicator.onlyForDiscrete,
  ),

  // Кнопки: filled = primary, elevated = secondary, outlined = outline, text = ghost
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _white,
      foregroundColor: _dark,
      disabledBackgroundColor: _white.withValues(alpha: .3),
      disabledForegroundColor: _dark.withValues(alpha: .6),
      overlayColor: _dark.withValues(alpha: .08),
      elevation: 0,
      minimumSize: const Size(64, 40),
      padding: _btnPad,
      shape: _shape,
      textStyle: _btnText,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _track,
      foregroundColor: _white,
      elevation: 0,
      shadowColor: Colors.transparent,
      overlayColor: Colors.white10,
      minimumSize: const Size(64, 40),
      padding: _btnPad,
      shape: _shape,
      textStyle: _btnText,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _white,
      overlayColor: Colors.white10,
      side: const BorderSide(color: _border),
      minimumSize: const Size(64, 40),
      padding: _btnPad,
      shape: _shape,
      textStyle: _btnText,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _white,
      overlayColor: Colors.white10,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: _shape,
      textStyle: _btnText,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: _muted,
      overlayColor: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _white,
    foregroundColor: _dark,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),

  // Поля
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0x0DFFFFFF), // white 5%
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    labelStyle: const TextStyle(color: _muted),
    hintStyle: const TextStyle(color: Color(0xFF71717A)),
    prefixIconColor: _muted,
    suffixIconColor: _muted,
    border: _fieldBorder,
    enabledBorder: _fieldBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFD4D4D8), width: 1.5), // ring
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF4444)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
    ),
  ),

  // Switch / Checkbox / Radio
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _dark : _white),
    trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _white : const Color(0xFF3F3F46)),
    trackOutlineColor: WidgetStateProperty.all(_border),
    trackOutlineWidth: WidgetStateProperty.all(1),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _white : Colors.transparent),
    checkColor: WidgetStateProperty.all(_dark),
    side: const BorderSide(color: Color(0xFF52525B), width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _white : const Color(0xFF52525B)),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),

  // Chips / Tabs / Segmented
  chipTheme: ChipThemeData(
    backgroundColor: _fill,
    selectedColor: const Color(0x29FFFFFF),
    side: const BorderSide(color: _border),
    shape: const StadiumBorder(),
    labelStyle: const TextStyle(fontSize: 13, color: _white),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    elevation: 0,
    pressElevation: 0,
  ),
  tabBarTheme: TabBarThemeData(
    labelColor: _white,
    unselectedLabelColor: _muted,
    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    indicator: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(8)),
    indicatorSize: TabBarIndicatorSize.tab,
    dividerColor: Colors.transparent,
    dividerHeight: 0,
    splashFactory: NoSplash.splashFactory,
    overlayColor: WidgetStateProperty.all(Colors.transparent),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? const Color(0x29FFFFFF) : Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _white : _muted),
      side: WidgetStateProperty.all(const BorderSide(color: _border)),
      shape: WidgetStateProperty.all(_shape),
      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      minimumSize: WidgetStateProperty.all(const Size(0, 36)),
    ),
  ),

  // Оверлеи
  dialogTheme: DialogThemeData(
    backgroundColor: _popover,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: _border),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: _popover,
    modalBackgroundColor: _popover,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: _popover,
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: _border),
    ),
    contentTextStyle: const TextStyle(color: _white, fontSize: 13),
    actionTextColor: _white,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: _popover,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: _border),
    ),
    textStyle: const TextStyle(color: _white, fontSize: 14),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    textStyle: const TextStyle(color: _white, fontSize: 14),
    menuStyle: MenuStyle(
      backgroundColor: WidgetStateProperty.all(_popover),
      elevation: WidgetStateProperty.all(8),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      )),
    ),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: _popover,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    textStyle: const TextStyle(color: _white, fontSize: 12),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  ),

  // Навигация / списки / прочее
  navigationBarTheme: NavigationBarThemeData(
    height: 64,
    backgroundColor: const Color(0xE609090B),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    indicatorColor: _border,
    iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? _white : _muted)),
    labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? _white : _muted)),
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: _muted,
    textColor: _white,
    titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _white),
    subtitleTextStyle: TextStyle(fontSize: 12, color: _muted),
    contentPadding: EdgeInsets.symmetric(horizontal: 12),
  ),
  dividerTheme: const DividerThemeData(color: Color(0x14FFFFFF), thickness: 1, space: 24),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: _white,
    linearTrackColor: _track,
    circularTrackColor: _track,
    linearMinHeight: 5,
    borderRadius: BorderRadius.circular(3),
  ),
  scrollbarTheme: ScrollbarThemeData(
    thickness: WidgetStateProperty.all(5),
    radius: const Radius.circular(3),
    thumbColor: WidgetStateProperty.all(const Color(0x33FFFFFF)),
  ),
);

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      extensions: [
        GraphComponentPalette(
          surface: AppColors.surface,
          surfaceBright: AppColors.surfaceBright,
          surfaceDim: AppColors.surfaceDim,
          surfaceContainer: AppColors.surfaceContainer,
          surfaceContainerHigh: AppColors.surfaceContainerHigh,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          borderGlass: AppColors.borderGlass,
        ),
      ],
        checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _white : Colors.transparent),
    checkColor: WidgetStateProperty.all(_dark),
    side: const BorderSide(color: Color(0xFF52525B), width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _white : const Color(0xFF52525B)),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),

  // Chips / Tabs / Segmented
  chipTheme: ChipThemeData(
    backgroundColor: _fill,
    selectedColor: const Color(0x29FFFFFF),
    side: const BorderSide(color: _border),
    shape: const StadiumBorder(),
    labelStyle: const TextStyle(fontSize: 13, color: _white),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    elevation: 0,
    pressElevation: 0,
  ),

      //Чтобы были одинаковые отступы и т.д
      visualDensity: VisualDensity.standard,
      brightness: Brightness.dark,
      //scaffoldBackgroundColor: AppColors.scaffoldBackgroundColor,
      primaryColor: AppColors.primary,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primaryContainer,
            brightness: Brightness.dark,
          ).copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            primaryContainer: AppColors.primaryContainer,
            onPrimaryContainer: Colors.white,
            secondary: AppColors.secondary,

            surface: AppColors.surface,
            surfaceBright: AppColors.surfaceBright,
            surfaceDim: AppColors.surfaceDim,
            onSurface: AppColors.onSurface,
            onSurfaceVariant: AppColors.onSurfaceVariant,

            surfaceContainerHigh: AppColors.surfaceContainerHigh,
            surfaceContainerLow: AppColors.surfaceContainerLow,

            outline: AppColors.inputBorderGlass,
            outlineVariant: AppColors.borderGlass,
          ),
      // Настройка глобального текстового филда под стиль Glass
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputGlass,
        contentPadding: const EdgeInsets.all(24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorderGlass),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorderGlass),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryContainer),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        elevation: 0,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTypography.codeLabel,
        ),
      ),

      textTheme: TextTheme(
        displayLarge: AppTypography.displayXL,
        headlineLarge: Platform.isAndroid
            ? AppTypography.headlineLgMobile
            : AppTypography.headlineLg,
        bodyMedium: AppTypography.bodyMd,
        bodySmall: AppTypography.bodySm,
        labelMedium: AppTypography.codeLabel,
      ),
    );
  }
}
