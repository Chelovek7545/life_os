import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/utils/date_format.dart';

Widget datePickButton(BuildContext context, {
    required String label,
    DateTime? date,
    required Function(DateTime newDate) onStartsAtChange,
  }) {
    return OutlinedButton(
      style: AppButtonStyles.baseButtonStyle,

      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2040),
        );
        if (selected != null) {
          onStartsAtChange(selected);
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            date == null ? label : formatDate(date),
            style: AppTypography.codeLabel.copyWith(color: Colors.white),
          ),
          // Spacer(),
          const Icon(Icons.calendar_today, size: 16),
        ],
      ),
    );
  }
