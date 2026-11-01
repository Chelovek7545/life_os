import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

class TelegramBotToggleButton extends StatelessWidget {
  const TelegramBotToggleButton({
    super.key,
    required this.isRunning,
    required this.onPressed,
    this.compact = false,
  });

  final ValueListenable<bool> isRunning;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: isRunning,
    builder: (context, running, child) => Tooltip(
      message: running ? 'Остановить Telegram-бота' : 'Запустить Telegram-бота',
      child: TextButton(
        key: const ValueKey('telegram_bot_toggle'),
        style:
            (running
                    ? AppButtonStyles.activeButtonStyle
                    : AppButtonStyles.baseButtonStyle)
                .copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.all(compact ? 10 : 16),
                  ),
                ),
        onPressed: onPressed,
        child: Text('TG', style: AppTypography.codeLabel),
      ),
    ),
  );
}
