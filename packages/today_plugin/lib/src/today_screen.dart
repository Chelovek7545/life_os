import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'today_plugin.dart' show TodayPanelSlots;

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.registry,
    required this.date,
    required this.onSelectDate,
    required this.now,
  });
  final PluginUiRegistry registry;
  final ValueListenable<DateTime> date;
  final ValueChanged<DateTime> onSelectDate;
  final DateTime Function() now;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
    valueListenable: date,
    builder: (context, selected, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final today = now();
        final isToday =
            selected.year == today.year &&
            selected.month == today.month &&
            selected.day == today.day;
        final tasks = PluginPanelSlot(
          key: const ValueKey('today-tasks-slot'),
          registry: registry,
          slot: TodayPanelSlots.tasks,
        );
        final habits = PluginPanelSlot(
          key: const ValueKey('today-habits-slot'),
          registry: registry,
          slot: TodayPanelSlots.habits,
        );
        final projects = PluginPanelSlot(
          key: const ValueKey('today-projects-slot'),
          registry: registry,
          slot: TodayPanelSlots.projects,
        );
        return SingleChildScrollView(
          key: const PageStorageKey('today-page'),
          padding: EdgeInsets.all(wide ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isToday ? 'Сегодня' : 'План на день',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Задачи, привычки и движение по проектам',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        key: const ValueKey('today-previous-day'),
                        tooltip: 'Предыдущий день',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => onSelectDate(
                          DateTime(
                            selected.year,
                            selected.month,
                            selected.day - 1,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('today-choose-date'),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${selected.day.toString().padLeft(2, '0')}.${selected.month.toString().padLeft(2, '0')}.${selected.year}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selected,
                            firstDate: DateTime(
                              selected.year < 2000 ? selected.year : 2000,
                            ),
                            lastDate: DateTime(
                              selected.year > 2100 ? selected.year : 2100,
                              12,
                              31,
                            ),
                          );
                          if (picked != null && context.mounted) {
                            onSelectDate(picked);
                          }
                        },
                      ),
                      IconButton(
                        key: const ValueKey('today-next-day'),
                        tooltip: 'Следующий день',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => onSelectDate(
                          DateTime(
                            selected.year,
                            selected.month,
                            selected.day + 1,
                          ),
                        ),
                      ),
                      if (!isToday)
                        TextButton(
                          onPressed: () => onSelectDate(now()),
                          child: const Text('К сегодняшнему дню'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      key: const ValueKey('today-wide-layout'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: tasks),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              habits,
                              const SizedBox(height: 20),
                              projects,
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      key: const ValueKey('today-narrow-layout'),
                      children: [
                        tasks,
                        const SizedBox(height: 20),
                        habits,
                        const SizedBox(height: 20),
                        projects,
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
