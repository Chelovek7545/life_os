import 'package:flutter/material.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool isGenerating;
  final String hintText;
  final String disabledHintText;
  final VoidCallback? onSend;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.isGenerating = false,
    this.hintText = 'Задайте системный вопрос архитектору...',
    this.disabledHintText = 'Требуется инициализация ядра...',
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled && !isGenerating,
              style: const TextStyle(color: Colors.white70),
              decoration: InputDecoration(
                hintText: enabled ? hintText : disabledHintText,
                hintStyle: const TextStyle(color: Colors.white30),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSend?.call(),
            ),
          ),
          GestureDetector(
            onTap: (enabled && !isGenerating) ? onSend : null,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (enabled && !isGenerating)
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.01),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isGenerating
                      ? Icons.hourglass_top_rounded
                      : Icons.send_rounded,
                  color: (enabled && !isGenerating)
                      ? Colors.white70
                      : Colors.white24,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
