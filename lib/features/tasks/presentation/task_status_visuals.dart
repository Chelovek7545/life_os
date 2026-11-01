import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';

extension TaskStatusVisuals on TaskStatus {
  String get title => switch (this) {
    TaskStatus.open => 'Open',
    TaskStatus.notStarted => 'To Do',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.done => 'Done',
  };
  String get subtitle => switch (this) {
    TaskStatus.open => 'Pending analysis',
    TaskStatus.notStarted => 'Awaiting deployment',
    TaskStatus.inProgress => 'Active execution',
    TaskStatus.done => 'Mission complete',
  };
  String get symbol => switch (this) {
    TaskStatus.open => '…',
    TaskStatus.notStarted => '○',
    TaskStatus.inProgress => '▶',
    TaskStatus.done => '✓',
  };
  Color get color => switch (this) {
    TaskStatus.open => Colors.blueGrey,
    TaskStatus.notStarted => Colors.redAccent,
    TaskStatus.inProgress => Colors.amberAccent,
    TaskStatus.done => Colors.lightGreenAccent,
  };
  IconData get icon => switch (this) {
    TaskStatus.open => Icons.pending_actions,
    TaskStatus.notStarted => Icons.radio_button_unchecked,
    TaskStatus.inProgress => Icons.hourglass_top,
    TaskStatus.done => Icons.check_circle_outline,
  };
}
