import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

@Preview()
Widget segmentedControlPreview() => MaterialApp(
  theme: ThemeData.light(),
  home: StatusSegmentedControl(
    selectedStatus: TaskStatus.notStarted,
    onStatusChanged: (status) {},
  ),
);

@Preview()
Widget statusDropdownMenuPreview() => MaterialApp(
  theme: ThemeData.light(),
  home: Scaffold(
    backgroundColor: const Color(0xFF121212),
    body: Center(
      child: StatusDropdownMenu(
        selectedStatus: TaskStatus.notStarted,
        onStatusChanged: (status) {},
      ),
    ),
  ),
);

class StatusDropdownMenu extends StatefulWidget {
  final TaskStatus selectedStatus;
  final ValueChanged<TaskStatus> onStatusChanged;

  const StatusDropdownMenu({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  State<StatusDropdownMenu> createState() => _StatusDropdownMenuState();
}

class _StatusDropdownMenuState extends State<StatusDropdownMenu> {
  bool _isExpanded = true; // Сделано открытым по умолчанию, как на макете

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFFF5722);
    const darkBg = Color(0xFF16181D);
    const cardBg = Color(0xFF22252B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Заголовок
        const Text(
          'MISSION STATUS',
          style: TextStyle(
            color: Color(0xFF8E929B),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Главная кнопка выбора
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: darkBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  widget.selectedStatus.icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.selectedStatus.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),

        // Выпадающий список
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: TaskStatus.values.map((status) {
                final isSelected = status == widget.selectedStatus;

                return InkWell(
                  onTap: () {
                    widget.onStatusChanged(status);
                    setState(() => _isExpanded = false);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.08)
                          : Colors.transparent,
                      border: isSelected
                          ? const Border(
                              left: BorderSide(color: accentColor, width: 3),
                            )
                          : null,
                    ),
                    padding: EdgeInsets.only(
                      left: isSelected ? 13 : 16, // Компенсация ширины Border
                      right: 16,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status.icon,
                          color: isSelected ? accentColor : const Color(0xFF8E929B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.title,
                              style: TextStyle(
                                color: isSelected ? accentColor : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.subtitle,
                              style: TextStyle(
                                color: isSelected
                                    ? accentColor.withOpacity(0.7)
                                    : const Color(0xFF6C717B),
                                fontSize: 11,
                                fontFamily: 'monospace', // Футуристичный моноширинный шрифт
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class StatusSegmentedControl extends StatelessWidget {
  final TaskStatus selectedStatus;
  final ValueChanged<TaskStatus> onStatusChanged;

  const StatusSegmentedControl({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TaskStatus.values.map((status) {
          final isSelected = status == selectedStatus;
          return GestureDetector(
            onTap: () => onStatusChanged(status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.transparent : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: const Color(0xFFFF5722), width: 1.5)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                status.title.toUpperCase(),
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFFF5722)
                      : const Color(0xFF8E929B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
