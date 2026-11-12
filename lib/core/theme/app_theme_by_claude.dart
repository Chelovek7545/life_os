// pubspec.yaml: google_fonts: ^6.2.1
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// shadcn "zinc" palette + glass surfaces.
class AppColors {
  // Dark
  static const dBg = Color(0xFF09090B);
  static const dFg = Color(0xFFFAFAFA);
  static const dMuted = Color(0xFFA1A1AA);
  static const dBorder = Color(0xFF27272A);
  // Light
  static const lBg = Color(0xFFFAFAFA);
  static const lFg = Color(0xFF09090B);
  static const lMuted = Color(0xFF71717A);
  static const lBorder = Color(0xFFE4E4E7);

  static const destructive = Color(0xFFEF4444);
  static const accentA = Color(0xFF6366F1); // blobs behind glass
  static const accentB = Color(0xFFEC4899);
}

const double kRadius = 10; // shadcn --radius: 0.625rem

class AppThemeNew {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final fg = isDark ? AppColors.dFg : AppColors.lFg;
    final bg = isDark ? AppColors.dBg : AppColors.lBg;
    final muted = isDark ? AppColors.dMuted : AppColors.lMuted;
    final border = isDark ? AppColors.dBorder : AppColors.lBorder;
    final primary = fg; // shadcn: primary = foreground (monochrome)
    final onPrimary = bg;

    // Glass surface (semi-transparent) and its hairline border
    final glass = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.55);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.8);
    // Overlays (menus, dialogs) are more opaque for readability
    final overlay = isDark
        ? const Color(0xFF18181B).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    final scheme = ColorScheme(
      brightness: b,
      primary: primary,
      onPrimary: onPrimary,
      secondary: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
      onSecondary: fg,
      error: AppColors.destructive,
      onError: Colors.white,
      surface: bg,
      onSurface: fg,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest: glass,
    );

    final radius = BorderRadius.circular(kRadius);
    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c, width: w),
        );

    final baseText = ThemeData(brightness: b).textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseText)
        .apply(bodyColor: fg, displayColor: fg)
        .copyWith(
          titleLarge: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: fg),
          titleMedium: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: fg),
          bodyMedium: GoogleFonts.inter(fontSize: 14, color: fg),
          bodySmall: GoogleFonts.inter(fontSize: 12, color: muted),
          labelLarge: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500, color: fg),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent, // use GlassBackground
      canvasColor: bg,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: fg),
      ),

      cardTheme: CardThemeData(
        color: glass,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius + 4),
          side: BorderSide(color: glassBorder),
        ),
      ),

      // ---- Buttons ----
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: glass,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: BorderSide(color: glassBorder),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ---- Inputs ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        border: inputBorder(glassBorder),
        enabledBorder: inputBorder(glassBorder),
        focusedBorder: inputBorder(fg.withValues(alpha: 0.5), 1.5), // ring
        errorBorder: inputBorder(AppColors.destructive),
        focusedErrorBorder: inputBorder(AppColors.destructive, 1.5),
      ),

      // ---- Dropdowns / menus ----
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: glass,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: inputBorder(glassBorder),
          enabledBorder: inputBorder(glassBorder),
          focusedBorder: inputBorder(fg.withValues(alpha: 0.5), 1.5),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(overlay),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: glassBorder),
          )),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: glassBorder),
        ),
        textStyle: textTheme.bodyMedium,
      ),

      // ---- Switch / Checkbox / Radio / Slider ----
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? primary
                : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8))),
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? onPrimary : fg.withValues(alpha: 0.9)),
        thumbIcon: const WidgetStatePropertyAll(null),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: muted, width: 1),
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primary : Colors.transparent),
        checkColor: WidgetStatePropertyAll(onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primary : muted),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: primary,
        inactiveTrackColor: fg.withValues(alpha: 0.12),
        thumbColor: bg,
        overlayColor: fg.withValues(alpha: 0.08),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        trackShape: const RoundedRectSliderTrackShape(),
      ),

      // ---- Overlays ----
      dialogTheme: DialogThemeData(
        backgroundColor: overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius + 4),
          side: BorderSide(color: glassBorder),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: glassBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: overlay,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: glassBorder),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(6)),
        textStyle: TextStyle(color: onPrimary, fontSize: 12),
      ),

      // ---- Navigation / chips ----
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: glass,
        surfaceTintColor: Colors.transparent,
        indicatorColor: fg.withValues(alpha: 0.1),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: fg, size: 22)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glass,
        selectedColor: primary,
        side: BorderSide(color: glassBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: textTheme.labelLarge,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: fg.withValues(alpha: 0.12),
      ),
    );
  }
}

/// Blurred glass panel. Theme alone can't blur, so use this for hero cards,
/// bottom bars and anything that should show the background through.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = kRadius + 4,
    this.blur = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.55),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.8),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Soft gradient + blurred color blobs. Glass needs something behind it.
/// Wrap your screens: GlassBackground(child: Scaffold(...)).
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
              color: isDark ? AppColors.dBg : AppColors.lBg),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: _Blob(AppColors.accentA.withValues(alpha: isDark ? 0.35 : 0.30), 320),
        ),
        Positioned(
          bottom: -140,
          right: -100,
          child: _Blob(AppColors.accentB.withValues(alpha: isDark ? 0.25 : 0.22), 340),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob(this.color, this.size);
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/* ---------- Usage ----------

MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.system,
  builder: (context, child) => GlassBackground(child: child!),
  home: const HomePage(),
);

Inside a screen:
  GlassCard(child: Column(children: [...]))
*/
