import 'package:flutter/material.dart';

enum DashboardWidgetType {
  tasks,
  timer,
  habits,
  calendar,
  statistics,
  projects;

  String get displayName {
    return switch (this) {
      DashboardWidgetType.tasks => 'Tasks',
      DashboardWidgetType.timer => 'Timer',
      DashboardWidgetType.habits => 'Habits',
      DashboardWidgetType.calendar => 'Calendar',
      DashboardWidgetType.statistics => 'Stats',
      DashboardWidgetType.projects => 'Projects',
    };
  }

  IconData get icon {
    return switch (this) {
      DashboardWidgetType.tasks => Icons.checklist_rounded,
      DashboardWidgetType.timer => Icons.timer_rounded,
      DashboardWidgetType.habits => Icons.repeat_rounded,
      DashboardWidgetType.calendar => Icons.calendar_month_rounded,
      DashboardWidgetType.statistics => Icons.bar_chart_rounded,
      DashboardWidgetType.projects => Icons.hub_outlined,
    };
  }

  int get defaultW {
    return switch (this) {
      DashboardWidgetType.tasks => 8,
      DashboardWidgetType.timer => 4,
      DashboardWidgetType.habits => 4,
      DashboardWidgetType.calendar => 8,
      DashboardWidgetType.statistics => 4,
      DashboardWidgetType.projects => 4,
    };
  }

  int get defaultH {
    return switch (this) {
      DashboardWidgetType.tasks => 3,
      DashboardWidgetType.timer => 2,
      DashboardWidgetType.habits => 3,
      DashboardWidgetType.calendar => 2,
      DashboardWidgetType.statistics => 2,
      DashboardWidgetType.projects => 2,
    };
  }
}
