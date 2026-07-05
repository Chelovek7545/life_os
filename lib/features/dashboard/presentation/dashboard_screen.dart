import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/features/dashboard/presentation/ai_assistant_view_model.dart';
import 'package:life_os/features/dashboard/presentation/chat_input_field.dart';
import 'package:life_os/features/dashboard/presentation/chat_streaming_text.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestStoragePermission() async {
  final status = await Permission.manageExternalStorage.request();

  if (status.isGranted) {
    debugPrint('✅ Доступ к файловому хранилищу получен');
  } else if (status.isDenied) {
    debugPrint('❌ Доступ к файловому хранилищу отклонён');
  } else if (status.isPermanentlyDenied) {
    debugPrint('⚠️ Доступ запрещён навсегда, откройте настройки');
    await openAppSettings();
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.viewModel,
    required this.aiViewModel,
  });
  final DashboardViewModel viewModel;
  final AIAssistantViewModel aiViewModel;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  Future<void> _installModel() async {
    await requestStoragePermission();
    print("asked");
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final installOptions = ModelInstallOptions(
      modelType: ModelType.gemma4,
      fileType: isAndroid ? ModelFileType.task : ModelFileType.litertlm,
      source: r'/storage/emulated/0/Download/gemma3-1b-it-int4.task',
      fromAsset: !isAndroid,
      description: isAndroid
          ? 'Install task model from external storage'
          : 'Install bundled litertlm model from assets',
    );

    try {
      await widget.aiViewModel.installModel(options: installOptions);
    } catch (e) {
      debugPrint('Error installing model: $e');
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50;
    if (atBottom != _autoScroll) {
      setState(() => _autoScroll = atBottom);
    }
  }

  void _scrollToBottom() {
    setState(() {
      _autoScroll = true;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottomIfAuto() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.aiViewModel.generating) {
      widget.aiViewModel.sendMessage(text);
      _controller.clear();
    }
    setState(() {
      
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.aiViewModel.messageTextStream.listen((t) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToBottomIfAuto(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildAiSection(),
            const SizedBox(height: 24),
            _buildCardsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSection() {
    return StreamBuilder<ModelInstallState>(
      stream: widget.aiViewModel.installState,
      initialData: const ModelInstallState(),
      builder: (context, snapshot) {
        final installState = snapshot.data ?? const ModelInstallState();

        if (!installState.ready) {
          return _buildInstallScreen(installState);
        }

        return _buildChatPanel();
      },
    );
  }

  Widget _buildInstallScreen(ModelInstallState installState) {
    return Center(
      child: GlassPanel(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            if (installState.installing) ...[
              CircularProgressIndicator(value: installState.progress),
              const SizedBox(height: 16),
              Text(installState.status, style: AppTypography.codeLabel),
            ] else ...[
              Text("Model is not installed", style: AppTypography.codeLabel),
              const SizedBox(height: AppMargins.md),
              ElevatedButton(
                style: AppButtonStyles.saveButton,
                onPressed: _installModel,
                child: const Text("Install model"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return GlassPanel(
      child: Container(
        padding: EdgeInsets.all(AppSpacing.xl),
        height: 500,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  StreamBuilder<AiAssistantState>(
                    stream: widget.aiViewModel.state,
                    builder: (context, snapshot) {
                      final messages = snapshot.data?.messages ?? [];

                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'Начните диалог',
                            style: TextStyle(color: Colors.white38),
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: _scrollController,
                        itemCount: messages.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, index) {
                          final isLast = index == messages.length - 1;
                          final msg = messages[index];

                          final isStreamingNow =
                              isLast &&
                              !msg.isUser &&
                              widget.aiViewModel.generating;

                          return _buildMessageBubble(
                            isUser: msg.isUser,
                            text: msg.text,
                            isStreamingNow: isStreamingNow,
                            messageTextStream:
                                widget.aiViewModel.messageTextStream,
                          );
                        },
                      );
                    },
                  ),
                  if (!_autoScroll)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildTextInputField(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputField() {
    return ChatInputField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: true,
      isGenerating: widget.aiViewModel.generating,
      hintText: 'Задайте системный вопрос архитектору...',
      disabledHintText: 'Требуется инициализация ядра...',
      onSend: _sendMessage,
    );
  }

  Widget _buildCardsSection() {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      height: 500,
      child: StreamBuilder(
        stream: widget.viewModel.state,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }

          return asyncSnapshot.data!.when(
            initial: () => const Center(child: Text("initial")),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e) => Text(e),
            loaded: (items) {
              return Wrap(
                children: items
                    .map(
                      (i) => _Card(
                        title: i.title,
                        subtitle: i.value,
                        icon: i.icon,
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }
}

Widget _buildAvatar(IconData icon, Color iconColor, {Color? borderColor}) {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: borderColor == null ? Colors.white.withOpacity(0.05) : null,
      border: borderColor != null ? Border.all(color: borderColor) : null,
    ),
    child: Icon(icon, color: iconColor, size: 20),
  );
}

Widget _buildMessageBubble({
  required bool isUser,
  required String text,
  bool isStreamingNow = false,
  Stream<String>? messageTextStream,
}) {
  const userTextStyle = TextStyle(color: Colors.white, fontSize: 15);
  const botTextStyle = TextStyle(
    color: Colors.white,
    height: 1.4,
    fontSize: 15,
  );

  if (isUser) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 36), //Размер аватарки

        Flexible(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.deepOrange,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(text, softWrap: true, style: userTextStyle),
          ),
        ),
        const SizedBox(width: 8),
        _buildAvatar(
          Icons.person_outline_rounded,
          Colors.white.withOpacity(0.5),
        ),
      ],
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _buildAvatar(
        Icons.psychology_rounded,
        Colors.deepOrange,
        borderColor: Colors.deepOrange.withOpacity(0.5),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: AnimatedContainer(
          margin: const EdgeInsets.all(8.0),
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: isStreamingNow && messageTextStream != null
              ? GemmaStreamFadeInText(
                  tokenStream: messageTextStream,
                  textStyle: botTextStyle,
                  fadeDuration: const Duration(milliseconds: 250),
                )
              : Text(text, style: botTextStyle),
        ),
      ),
    ],
  );
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _Card({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GemmaStreamFadeInText extends StatefulWidget {
  final Stream<String> tokenStream;
  final TextStyle textStyle;
  final Duration fadeDuration;

  const GemmaStreamFadeInText({
    super.key,
    required this.tokenStream,
    required this.textStyle,
    this.fadeDuration = const Duration(milliseconds: 250),
  });

  @override
  State<GemmaStreamFadeInText> createState() => _GemmaStreamFadeInTextState();
}

class _GemmaStreamFadeInTextState extends State<GemmaStreamFadeInText>
    with SingleTickerProviderStateMixin {
  final List<AnimatedToken> _tokens = [];
  StreamSubscription<String>? _subscription;
  late final Ticker _ticker;
  Duration _currentElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((Duration elapsed) {
      _currentElapsed = elapsed;
      final hasActiveAnimations = _tokens.any(
        (t) => t.getOpacity(_currentElapsed, widget.fadeDuration) < 1.0,
      );
      if (hasActiveAnimations) {
        setState(() {});
      }
    });
    _ticker.start();

    _subscription = widget.tokenStream.listen((token) {
      if (token.isNotEmpty) {
        setState(() {
          _tokens.add(
            AnimatedToken(text: token, startDuration: _currentElapsed),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamingCustomText(
      tokens: _tokens,
      currentElapsed: _currentElapsed,
      textStyle: widget.textStyle,
      fadeDuration: widget.fadeDuration,
    );
  }
}
