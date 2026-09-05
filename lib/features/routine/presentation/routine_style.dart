import 'package:flutter/material.dart';

const routineAccent = Color(0xFFF38B64);

class RoutinePalette {
  const RoutinePalette(this.dark);
  final bool dark;
  Color get background =>
      dark ? const Color(0xFF15171E) : const Color(0xFFF0F2F7);
  Color get surface => dark ? const Color(0xFF22252F) : const Color(0xFFFCFCFE);
  Color get inset => dark ? const Color(0xFF2B2F3C) : const Color(0xFFF0F2F7);
  Color get text => dark ? const Color(0xFFF2F3F7) : const Color(0xFF24283A);
  Color get secondary =>
      dark ? const Color(0xFFAEB5C8) : const Color(0xFF646D84);
  Color get border => dark ? const Color(0xFF3A3F4E) : const Color(0xFFDDE1EB);
  ThemeData get theme => ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: 'Inter',
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: routineAccent,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          surface: surface,
          onSurface: text,
          primary: dark ? const Color(0xFFFFB79A) : const Color(0xFFAD4B25),
        ),
    scaffoldBackgroundColor: background,
    dividerColor: border,
    textTheme: (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: text,
      displayColor: text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inset,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 450),
    ),
  );
}

RoutinePalette paletteOf(BuildContext context) =>
    RoutinePalette(Theme.of(context).brightness == Brightness.dark);

class RoutineSurface extends StatelessWidget {
  const RoutineSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border.withValues(alpha: .7)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class RoutineEmpty extends StatelessWidget {
  const RoutineEmpty({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.icon = Icons.spa_outlined,
  });
  final String title;
  final String subtitle;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: routineAccent),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: paletteOf(context).secondary, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class RoutineMetric extends StatelessWidget {
  const RoutineMetric({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });
  final String label;
  final String value;
  final String? caption;
  @override
  Widget build(BuildContext context) => RoutineSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: paletteOf(context).secondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption!,
            style: TextStyle(color: paletteOf(context).secondary, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}
