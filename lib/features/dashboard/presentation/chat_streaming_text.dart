
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AnimatedToken {
  final String text;
  final Duration startDuration; // Таймстамп кадра движка, на котором пришел токен

  AnimatedToken({required this.text, required this.startDuration});

  // Расчет opacity на основе текущего кадра движка
  double getOpacity(Duration currentElapsed, Duration fadeDuration) {
    final elapsed = currentElapsed - startDuration;
    if (elapsed >= fadeDuration) return 1.0;
    if (elapsed <= Duration.zero) return 0.0;
    
    return elapsed.inMicroseconds / fadeDuration.inMicroseconds;
  }
}

class StreamingCustomText extends LeafRenderObjectWidget {
  final List<AnimatedToken> tokens;
  final Duration currentElapsed;
  final TextStyle textStyle;
  final Duration fadeDuration;

  const StreamingCustomText({
    super.key,
    required this.tokens,
    required this.currentElapsed,
    required this.textStyle,
    required this.fadeDuration,
  });

  @override
  RenderStreamingText createRenderObject(BuildContext context) {
    return RenderStreamingText(
      tokens: tokens,
      currentElapsed: currentElapsed,
      textStyle: textStyle,
      fadeDuration: fadeDuration,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderStreamingText renderObject) {
    renderObject
      ..tokens = tokens
      ..currentElapsed = currentElapsed // Срабатывает сеттер внутри RenderBox
      ..textStyle = textStyle
      ..fadeDuration = fadeDuration;
  }
}

class RenderStreamingText extends RenderBox {
  RenderStreamingText({
    required List<AnimatedToken> tokens,
    required Duration currentElapsed,
    required TextStyle textStyle,
    required Duration fadeDuration,
  })  : _tokens = tokens,
        _currentElapsed = currentElapsed,
        _textStyle = textStyle,
        _fadeDuration = fadeDuration {
    _textPainter = TextPainter(textDirection: TextDirection.ltr);
  }

  List<AnimatedToken> _tokens;
  Duration _currentElapsed;
  TextStyle _textStyle;
  Duration _fadeDuration;
  
  // Единственный маляр для всего текста
  late final TextPainter _textPainter;

  // Изменение токенов меняет и структуру текста, и его размеры
  set tokens(List<AnimatedToken> value) {
    if (_tokens == value) return;
    _tokens = value;
    markNeedsLayout(); // Новые токены = нужно пересчитать высоту пузыря
  }

  // Изменение времени меняет ТОЛЬКО прозрачность (цвета), размеры текста остаются прежними
  set currentElapsed(Duration value) {
    if (_currentElapsed == value) return;
    _currentElapsed = value;
    markNeedsLayout(); 
    // Нам нужен именно layout, так как мы пересобираем TextSpan дерево. 
    // Благодаря внутренней оптимизации Flutter, если текст не изменился, 
    // повторный layout пройдет моментально.
  }

  set textStyle(TextStyle value) {
    if (_textStyle == value) return;
    _textStyle = value;
    markNeedsLayout();
  }

  set fadeDuration(Duration value) {
    if (_fadeDuration == value) return;
    _fadeDuration = value;
  }

  // Метод сборки дерева TextSpan с индивидуальными анимациями прозрачности
  TextSpan _buildTextSpanTree() {
    final List<InlineSpan> children = [];

    for (final token in _tokens) {
      final opacity = token.getOpacity(_currentElapsed, _fadeDuration);

      // Создаем индивидуальный Paint для цвета этого конкретного токена
      final tokenPaint = Paint()
        ..color = _textStyle.color!.withOpacity(opacity);

      children.add(
        TextSpan(
          text: token.text,
          style: _textStyle.copyWith(foreground: tokenPaint),
        ),
      );
    }

    return TextSpan(children: children);
  }

  @override
  void performLayout() {
    // 1. Собираем актуальное дерево текста со всеми прозрачностями
    _textPainter.text = _buildTextSpanTree();

    // 2. Даем команду движку разметить текст по текущей ширине экрана/контейнера
    _textPainter.layout(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
    );

    // 3. Динамически выставляем точный размер виджета! 
    // Пузырь будет мягко расти вниз по мере появления новых строк.
    size = constraints.constrain(_textPainter.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Просто рисуем готовый, идеально заверстанный текст в один вызов
    _textPainter.paint(context.canvas, offset);
  }

  @override
  void dispose() {
    _textPainter.dispose();
    super.dispose();
  }
}