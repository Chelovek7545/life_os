import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';

Widget dateAndTimePickButton(
  BuildContext context, {
  required String label,
  DateTime? date,
  required ValueChanged<DateTime?> onDateChange,
  required bool Function(DateTime) validate,
}) {
  void _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    final dt = date?.copyWith(
          year: selected?.year,
          month: selected?.month,
          day: selected?.day,
        ) ??
        selected?.add(const Duration(milliseconds: 1));
    if (selected != null){

      if(
          validate(
            dt!
          )) {
        onDateChange(
          dt
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
      }
    }
  }

  void _chooseTime() async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date!),
    );

    if (selectedTime != null) {
      final dt = DateTime(
        date.year,
        date.month,
        date.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      if (validate(dt)) {
        onDateChange(dt);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
      }
    }
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    crossAxisAlignment: CrossAxisAlignment.center,
    //alignment: AlignmentDirectional.topEnd,
    children: [
      Container(
        constraints: BoxConstraints(minWidth: 120, maxWidth: 160),
        child: AspectRatio(
          aspectRatio: 5 / 6,
          child: OutlinedButton(
            style: AppButtonStyles.baseButtonStyle,

            onPressed: _chooseDate,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppColors.secondary,
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
                                    style: AppButtonStyles.activeButtonStyle
                                        .copyWith(
                                          padding: MaterialStateProperty.all(
                                            EdgeInsets.all(16),
                                          ),
                                        ),
                                    onPressed: () => onDateChange(null),
                                    icon: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                )
                              : SizedBox(width: 0),
                        ),
                      ],
                    ),
                    SizedBox(height: AppMargins.lg),

                    Text(
                      label,
                      style: AppTypography.codeLabel.copyWith(
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppMargins.xs),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        date == null ? "no date" : formatDate(date),
                        style: AppTypography.codeLabel.copyWith(
                          color: date == null ? Colors.white54 : Colors.white,
                        ),
                      ),
                      SizedBox(height: AppMargins.xs),
                      TextButton(
                        style: TextButton.styleFrom(
                          textStyle: AppTypography.codeLabel.copyWith(
                            fontSize: 26,
                            color: Colors.white,
                          ),
                        ),
                        //style: AppButtonStyles.baseButtonStyle,
                        child: Text(
                          date == null || date.isDateOnly
                              ? "Time"
                              : formatTimeOfDate(date),
                        ),
                        onPressed: date != null ? _chooseTime : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
