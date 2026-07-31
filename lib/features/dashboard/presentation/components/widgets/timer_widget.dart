import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

/// Простой таймер (секундомер) внутри виджета дашборда.
///
/// Счётчик с точностью до секунд, кнопки play/pause и reset.
/// Состояние — локальное (не сохраняется между перезапусками).
///
/// [Timer.periodic] запускается/останавливается при нажатии.
class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  bool _isRunning = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds++);
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _seconds = 0;
    });
  }

  String get _formatted {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Timer',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const Spacer(),
        Center(
          child: Text(
            _formatted,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallButton(
              icon: _isRunning ? Icons.pause : Icons.play_arrow,
              onTap: _toggle,
            ),
            const SizedBox(width: 8),
            _SmallButton(icon: Icons.refresh, onTap: _reset),
          ],
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.onSurface),
      ),
    );
  }
}
