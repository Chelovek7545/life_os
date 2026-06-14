import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class TimelinePainter extends CustomPainter {
  final List<double> markerOffsets;

  TimelinePainter({
    required this.markerOffsets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final markerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25);

    final glowPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        6,
      );

    const lineX = 25.0;

    // Основная линия
    canvas.drawLine(
      Offset(lineX, 0),
      Offset(lineX, size.height),
      linePaint,
    );

    // Маркеры времени
    for (final y in markerOffsets) {
      // Свечение
      canvas.drawCircle(
        Offset(lineX, y),
        5,
        glowPaint,
      );

      // Основная точка
      canvas.drawCircle(
        Offset(lineX, y),
        2.5,
        markerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) {
    return oldDelegate.markerOffsets != markerOffsets;
  }
}

@Preview(
  name: 'Explon Screen',
)
Widget explonPreview() {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Timeline(events: events),
  );
}

final events = [
      EventModel(
        title: 'UI Demo',
        subtitle: 'Buffer & rest zone',
        startTime: '3:30',
        color: Colors.white.withOpacity(0.08),
      ),
      EventModel(
        title: 'Pre workout lunch',
        subtitle: 'Buffer & rest zone',
        startTime: '4:00',
        color: Colors.white.withOpacity(0.08),
        icon: Icons.restaurant,
      ),
      EventModel(
        title: 'Daily Standup',
        subtitle: 'Buffer & rest zone',
        startTime: '5:00',
        color: Colors.white.withOpacity(0.08),
      ),
      EventModel(
        title: 'Resistance Training',
        subtitle: 'Commute included',
        startTime: '6:00',
        height: 120,
        color: const Color(0xFF556B2F),
        icon: Icons.fitness_center,
      ),
      EventModel(
        title: 'Book flight tickets',
        subtitle: 'Buffer & rest zone',
        startTime: '8:00',
        color: const Color(0xFF355C5C),
        icon: Icons.check_circle,
      ),
      EventModel(
        title: 'Explon Discussion',
        subtitle: 'Buffer & rest zone',
        startTime: '10:00',
        color: Colors.white.withOpacity(0.05),
      ),
      EventModel(
        title: 'Update table',
        subtitle: 'Buffer & rest zone',
        startTime: '10:15',
        color: Colors.white.withOpacity(0.08),
      ),
    ];

class ExplonScreen extends StatelessWidget {
  const ExplonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = [
      EventModel(
        title: 'UI Demo',
        subtitle: 'Buffer & rest zone',
        startTime: '3:30',
        color: Colors.white.withOpacity(0.08),
      ),
      EventModel(
        title: 'Pre workout lunch',
        subtitle: 'Buffer & rest zone',
        startTime: '4:00',
        color: Colors.white.withOpacity(0.08),
        icon: Icons.restaurant,
      ),
      EventModel(
        title: 'Daily Standup',
        subtitle: 'Buffer & rest zone',
        startTime: '5:00',
        color: Colors.white.withOpacity(0.08),
      ),
      EventModel(
        title: 'Resistance Training',
        subtitle: 'Commute included',
        startTime: '6:00',
        height: 120,
        color: const Color(0xFF556B2F),
        icon: Icons.fitness_center,
      ),
      EventModel(
        title: 'Book flight tickets',
        subtitle: 'Buffer & rest zone',
        startTime: '8:00',
        color: const Color(0xFF355C5C),
        icon: Icons.check_circle,
      ),
      EventModel(
        title: 'Explon Discussion',
        subtitle: 'Buffer & rest zone',
        startTime: '10:00',
        color: Colors.white.withOpacity(0.05),
      ),
      EventModel(
        title: 'Update table',
        subtitle: 'Buffer & rest zone',
        startTime: '10:15',
        color: Colors.white.withOpacity(0.08),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 20),

                /// Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white10,
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'explon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.green,
                        child: const Text(
                          '68',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                /// Calendar
                SizedBox(
                  height: 70,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: const [
                      DayWidget(day: 'M', date: '20'),
                      DayWidget(day: 'T', date: '21'),
                      DayWidget(
                        day: 'W',
                        date: '22',
                        selected: true,
                      ),
                      DayWidget(day: 'T', date: '23'),
                      DayWidget(day: 'F', date: '24'),
                      DayWidget(day: 'S', date: '25'),
                      DayWidget(day: 'S', date: '26'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                /// Timeline
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      100,
                    ),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 50,
                              child: Text(
                                event.startTime,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            Expanded(
                              child: EventCard(event: event),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            /// FAB
            Positioned(
              bottom: 32,
              right: 24,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  backgroundColor: Colors.white12,
                  elevation: 0,
                  onPressed: () {},
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final EventModel event;

  const EventCard({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
        ),
        child: Container(
          height: event.height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: event.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.subtitle,
                      style: TextStyle(
                        color:
                            Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (event.icon != null)
                Icon(
                  event.icon,
                  color: Colors.white70,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DayWidget extends StatelessWidget {
  final String day;
  final String date;
  final bool selected;

  const DayWidget({
    super.key,
    required this.day,
    required this.date,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white12
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              color: selected
                  ? Colors.red
                  : Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class EventModel {
  final String title;
  final String subtitle;
  final String startTime;
  final double height;
  final Color color;
  final IconData? icon;

  EventModel({
    required this.title,
    required this.subtitle,
    required this.startTime,
    required this.color,
    this.height = 70,
    this.icon,
  });
}


class Timeline extends StatelessWidget {
  final List<EventModel> events;

  const Timeline({
    super.key,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    double currentOffset = 0;

    final markers = <double>[];

    for (final event in events) {
      markers.add(currentOffset + event.height / 2);

      currentOffset += event.height + 12;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: TimelinePainter(
              markerOffsets: markers,
            ),
          ),
        ),

        ListView.separated(
          padding: const EdgeInsets.only(
            left: 8,
            right: 20,
            bottom: 100,
          ),
          itemCount: events.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final event = events[index];

            return SizedBox(
              height: event.height,
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 50,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: 12),
                      child: Text(
                        event.startTime,
                        style: TextStyle(
                          color:
                              Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: EventCard(
                      event: event,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
