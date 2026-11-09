import 'dart:async';
import 'dart:math' as math;
import 'package:agent_bridge/local_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'assistant_settings_form.dart';

class AssistantOverlay extends StatefulWidget {
  const AssistantOverlay({super.key, required this.controller});
  final AssistantController controller;
  @override
  State<AssistantOverlay> createState() => _AssistantOverlayState();
}

class _AssistantOverlayState extends State<AssistantOverlay> {
  bool _open = false;
  bool _settings = false;
  int _lastMessageCount = -1;
  final _draft = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  void _minimize() {
    _focus.unfocus();
    setState(() => _open = false);
  }

  void _send() {
    if (!widget.controller.isActive ||
        widget.controller.state.busy ||
        _draft.text.trim().isEmpty) {
      return;
    }
    final text = _draft.text;
    _draft.clear();
    unawaited(widget.controller.send(text));
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _draft.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AssistantState>(
    stream: widget.controller.changes,
    initialData: widget.controller.state,
    builder: (context, snapshot) {
      final state = snapshot.data ?? widget.controller.state;
      final colors = Theme.of(context).colorScheme;
      if (_open && _lastMessageCount != state.messages.length) {
        _lastMessageCount = state.messages.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final keyboardOverlap = math.max(
            0.0,
            constraints.maxHeight -
                (media.size.height - media.viewInsets.bottom),
          );
          final width = math.min(
            420.0,
            math.max(0.0, constraints.maxWidth - 24),
          );
          final height = math.min(
            620.0,
            math.max(0.0, constraints.maxHeight - keyboardOverlap - 24),
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + keyboardOverlap),
            child: Align(
              alignment: Alignment.bottomRight,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): _minimize,
                },
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  child: !_open
                      ? FloatingActionButton(
                          key: const ValueKey('assistant.toggle'),
                          heroTag: 'assistant.chat',
                          tooltip: 'Открыть помощника',
                          onPressed: () => setState(() {
                            _lastMessageCount = -1;
                            _open = true;
                          }),
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: const Icon(Icons.chat_bubble_outline_rounded),
                        )
                      : SizedBox(
                          key: const ValueKey('assistant.panel'),
                          width: width,
                          height: height,
                          child: Material(
                            elevation: 18,
                            shadowColor: Colors.black54,
                            color: colors.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    8,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_outlined,
                                        color: colors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Помощник',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              state.backendInfo == null
                                                  ? 'Локально · ${state.settings.device}'
                                                  : '${state.backendInfo!.device} · подключён',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        key: const ValueKey('assistant.clear'),
                                        tooltip: 'Новый диалог',
                                        onPressed: state.busy
                                            ? null
                                            : widget.controller.clear,
                                        icon: const Icon(
                                          Icons.add_comment_outlined,
                                          size: 19,
                                        ),
                                      ),
                                      IconButton(
                                        key: const ValueKey(
                                          'assistant.settings',
                                        ),
                                        tooltip: 'Настройки модели',
                                        onPressed: state.busy
                                            ? null
                                            : () => setState(
                                                () => _settings = !_settings,
                                              ),
                                        icon: const Icon(
                                          Icons.tune_rounded,
                                          size: 19,
                                        ),
                                      ),
                                      IconButton(
                                        key: const ValueKey(
                                          'assistant.minimize',
                                        ),
                                        tooltip: 'Свернуть чат',
                                        onPressed: _minimize,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                if (_settings)
                                  Expanded(
                                    child: AssistantSettingsForm(
                                      settings: state.settings,
                                      busy: state.busy,
                                      onSave: (settings) async {
                                        await widget.controller.configure(
                                          settings,
                                        );
                                        if (mounted &&
                                            widget.controller.state.settings ==
                                                settings) {
                                          setState(() => _settings = false);
                                        }
                                      },
                                      onCancel: () =>
                                          setState(() => _settings = false),
                                    ),
                                  )
                                else ...[
                                  Expanded(
                                    child: state.messages.isEmpty
                                        ? _Welcome(
                                            onSettings: () => setState(
                                              () => _settings = true,
                                            ),
                                            onExample: (text) {
                                              _draft.text = text;
                                              _focus.requestFocus();
                                            },
                                          )
                                        : ListView.builder(
                                            key: const ValueKey(
                                              'assistant.messages',
                                            ),
                                            controller: _scroll,
                                            padding: const EdgeInsets.all(16),
                                            itemCount: state.messages.length,
                                            itemBuilder: (_, index) => _Message(
                                              message: state.messages[index],
                                            ),
                                          ),
                                  ),
                                  if (state.busy)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        8,
                                        4,
                                      ),
                                      child: Row(
                                        children: [
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              switch (state.phase) {
                                                AssistantPhase.loading =>
                                                  'Загрузка модели…',
                                                AssistantPhase.acting =>
                                                  'Выполняю действие…',
                                                AssistantPhase.configuring =>
                                                  'Сохраняю настройки…',
                                                _ => 'Готовлю ответ…',
                                              },
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ),
                                          IconButton(
                                            key: const ValueKey(
                                              'assistant.stop',
                                            ),
                                            tooltip: 'Остановить ответ',
                                            onPressed:
                                                state.phase ==
                                                    AssistantPhase.configuring
                                                ? null
                                                : () => unawaited(
                                                    widget.controller.cancel(),
                                                  ),
                                            icon: const Icon(
                                              Icons.stop_circle_outlined,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      12,
                                    ),
                                    child: CallbackShortcuts(
                                      bindings: {
                                        const SingleActivator(
                                          LogicalKeyboardKey.enter,
                                        ): _send,
                                      },
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              key: const ValueKey(
                                                'assistant.input',
                                              ),
                                              controller: _draft,
                                              focusNode: _focus,
                                              minLines: 1,
                                              maxLines: 4,
                                              maxLength: 2000,
                                              textCapitalization:
                                                  TextCapitalization.sentences,
                                              keyboardType:
                                                  TextInputType.multiline,
                                              decoration: const InputDecoration(
                                                hintText: 'Сообщение…',
                                                counterText: '',
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ValueListenableBuilder<
                                            TextEditingValue
                                          >(
                                            valueListenable: _draft,
                                            builder: (_, value, _) =>
                                                IconButton.filled(
                                                  key: const ValueKey(
                                                    'assistant.send',
                                                  ),
                                                  tooltip: 'Отправить',
                                                  onPressed:
                                                      state.busy ||
                                                          value.text
                                                              .trim()
                                                              .isEmpty
                                                      ? null
                                                      : _send,
                                                  icon: const Icon(
                                                    Icons.arrow_upward_rounded,
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSettings, required this.onExample});
  final VoidCallback onSettings;
  final ValueChanged<String> onExample;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.forum_outlined,
          size: 38,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text('Чем помочь?', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Найду задачи, добавлю новую или отмечу выполненную. Переписка остаётся на этом компьютере.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Найти задачи'),
              onPressed: () => onExample('Покажи мои незавершённые задачи'),
            ),
            ActionChip(
              label: const Text('Добавить задачу'),
              onPressed: () => onExample('Создай задачу: '),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Для первого запуска укажите папку модели и Python с OpenVINO.',
        ),
        TextButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Настроить модель'),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.message});
  final AssistantMessage message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = message.kind == AssistantMessageKind.user;
    final action = message.kind == AssistantMessageKind.action;
    final error = message.kind == AssistantMessageKind.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: user
                ? colors.primaryContainer.withValues(alpha: .22)
                : colors.surfaceContainerHigh.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(16),
            border: error
                ? Border.all(color: colors.error.withValues(alpha: .5))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (action || error) ...[
                    Icon(
                      error ? Icons.error_outline : Icons.check_circle_outline,
                      size: 14,
                      color: error ? colors.error : colors.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      user
                          ? 'Вы'
                          : action
                          ? 'Действие'
                          : error
                          ? 'Сообщение'
                          : 'Помощник',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(message.text),
            ],
          ),
        ),
      ),
    );
  }
}
