import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/utils/date_format.dart';

Widget datePickButton(
  BuildContext context, {
  required String label,
  DateTime? date,
  required ValueChanged<DateTime?> onDateChange,
}) {
  return Row(
    //alignment: AlignmentDirectional.topEnd,
    children: [
      Expanded(
        child: OutlinedButton(
          style: AppButtonStyles.baseButtonStyle,

          onPressed: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2040),
            );
            if (selected != null) {
              onDateChange(selected);
            }
          },
          child: Row(
            //mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                date == null ? label : formatDate(date),
                style: AppTypography.codeLabel.copyWith(color: Colors.white),
              ),
              const Icon(Icons.calendar_today, size: 16),
            ],
          ),
        ),
      ),
      AnimatedSize(
        // плавно меняет ширину от 0 до размера иконки
        duration: Duration(milliseconds: 200),
        reverseDuration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.centerLeft,
        child: date != null
            ? Padding(
                padding: EdgeInsets.only(left: 4),
                child: IconButton(
                style: AppButtonStyles.activeButtonStyle,
                onPressed: () => onDateChange(null),
                icon: Icon(Icons.close, size: 14, color: Colors.white70),
              ),
              )
            : SizedBox(width: 0),
      ),
    ],
  );
}
