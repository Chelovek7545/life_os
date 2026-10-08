import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/ui/glass_panel.dart';

/// Типы уведомлений и их стили
enum ToastType {
  error(
    icon: Icons.error_outline_rounded,
    iconColor: Color(0xFFFF453A),
    borderColor: Color(0x33FF453A),
  ),
  success(
    icon: Icons.check_circle_outline_rounded,
    iconColor: Color(0xFF30D158),
    borderColor: Color(0x3330D158),
  ),
  info(
    icon: Icons.info_outline_rounded,
    iconColor: Color(0xFF0A84FF),
    borderColor: Color(0x330A84FF),
  );

  final IconData icon;
  final Color iconColor;
  final Color borderColor;

  const ToastType({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
  });
}

/// Сервис для показа анимированных UI-уведомлений
abstract class AppNotification {
  static OverlayEntry? _currentEntry;

  /// Основной метод показа тоста
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 2600),
    Alignment alignment = Alignment.topCenter,
  }) {
    // Закрываем предыдущий тост, если он уже висит
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AnimatedToastWidget(
        message: message,
        type: type,
        alignment: alignment,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Быстрые методы для частых сценариев
  static void showError(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, type: ToastType.info);
  }
}

/// Приватный анимированный виджет тоста
class _AnimatedToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Alignment alignment;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AnimatedToastWidget({
    required this.message,
    required this.type,
    required this.alignment,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AnimatedToastWidget> createState() => _AnimatedToastWidgetState();
}

class _AnimatedToastWidgetState extends State<_AnimatedToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    final isTop = widget.alignment.y <= 0;
    final beginOffset = isTop ? const Offset(0, -0.4) : const Offset(0, 0.4);

    _offsetAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    Future.delayed(widget.duration, () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: widget.alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: GlassPanel(
                  //constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  // decoration: BoxDecoration(
                  //   color: const Color(0xFF2C2C2E),
                  //   borderRadius: BorderRadius.circular(14),
                  //   border: Border.all(color: widget.type.borderColor, width: 1),
                  //   boxShadow: [
                  //     BoxShadow(
                  //       color: Colors.black.withOpacity(0.25),
                  //       blurRadius: 16,
                  //       offset: const Offset(0, 6),
                  //     ),
                  //   ],
                  // ),
                  //borderRadius: AppRadius.xl,
                  color: AppColors.surfaceContainer.withValues(alpha: 0.9),
                  borderColor: widget.type.borderColor.withAlpha(100),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.type.icon,
                        color: widget.type.iconColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Удобное расширение для контекста
extension AppNotificationExtension on BuildContext {
  void showErrorToast(String message) =>
      AppNotification.showError(this, message);

  void showSuccessToast(String message) =>
      AppNotification.showSuccess(this, message);

  void showInfoToast(String message) =>
      AppNotification.showInfo(this, message);
}