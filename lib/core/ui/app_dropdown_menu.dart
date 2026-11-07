import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

class AppDropdownMenu<T> extends StatelessWidget {
  const AppDropdownMenu({
    super.key,
    required this.dropdownMenuEntries,
    required this.onSelected,
    this.initialSelection,
    this.hintText,
    this.width = 180,
    this.expandedInsets,
    this.leadingIcon,
    this.selectOnly = false,
    this.menuStyle,
    this.inputDecorationTheme,
  });

  final List<DropdownMenuEntry<T>> dropdownMenuEntries;
  final ValueChanged<T?>? onSelected;
  final T? initialSelection;
  final String? hintText;
  final double? width;
  final EdgeInsetsGeometry? expandedInsets;
  final Widget? leadingIcon;
  final bool selectOnly;
  final MenuStyle? menuStyle;
  final InputDecorationTheme? inputDecorationTheme;

  @override
  Widget build(BuildContext context) => DropdownMenu<T>(
    initialSelection: initialSelection,
    onSelected: onSelected,
    dropdownMenuEntries: dropdownMenuEntries,
    hintText: hintText,
    width: width,
    expandedInsets: expandedInsets,
    leadingIcon: leadingIcon,
    selectOnly: selectOnly,
    textStyle: AppTypography.bodySm,
    trailingIcon: const Icon(
      Icons.keyboard_arrow_down_rounded,
      color: AppColors.primary,
    ),
    selectedTrailingIcon: const Icon(
      Icons.keyboard_arrow_up_rounded,
      color: AppColors.primary,
    ),
    inputDecorationTheme:
        inputDecorationTheme ?? AppButtonStyles.baseInputDecoration,
    menuStyle:
        menuStyle ??
        MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(
            AppColors.surfaceContainerLow,
          ),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
  );
}
