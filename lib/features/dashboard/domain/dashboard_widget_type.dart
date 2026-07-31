import 'package:flutter/material.dart';

enum DashboardWidgetType {
  tasks,
  timer,
  habits,
  calendar;

  String get displayName {
    return switch (this) {
      DashboardWidgetType.tasks => 'Tasks',
      DashboardWidgetType.timer => 'Timer',
      DashboardWidgetType.habits => 'Habits',
      DashboardWidgetType.calendar => 'Calendar',
    };
  }

  IconData get icon {
    return switch (this) {
      DashboardWidgetType.tasks => Icons.checklist_rounded,
      DashboardWidgetType.timer => Icons.timer_rounded,
      DashboardWidgetType.habits => Icons.repeat_rounded,
      DashboardWidgetType.calendar => Icons.calendar_month_rounded,
    };
  }

  int get defaultW {
    return switch (this) {
      DashboardWidgetType.tasks => 8,
      DashboardWidgetType.timer => 4,
      DashboardWidgetType.habits => 4,
      DashboardWidgetType.calendar => 8,
    };
  }

  int get defaultH {
    return switch (this) {
      DashboardWidgetType.tasks => 3,
      DashboardWidgetType.timer => 2,
      DashboardWidgetType.habits => 3,
      DashboardWidgetType.calendar => 2,
    };
  }
}
