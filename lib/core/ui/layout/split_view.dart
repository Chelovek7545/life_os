import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Builder для кастомного разделителя.
typedef SplitDividerBuilder = Widget Function(
  BuildContext context,
  int dividerIndex,
  Axis axis,
);

/// Переиспользуемый split-view с изменяемыми размерами панелей.
///
/// [axis] — направление разделения:
/// - Axis.horizontal — панели слева направо;
/// - Axis.vertical — панели сверху вниз.
///
/// [children] — панели, которые нужно разместить.
///
/// [weights] — контролируемые веса панелей.
/// Если передать [weights], виджет будет работать в контролируемом режиме.
/// Родитель должен обновлять [weights] через [onWeightsChanged].
///
/// [initialWeights] — начальные веса для неконтролируемого режима.
///
/// [minSizes] — минимальные размеры панелей вдоль основной оси.
/// Для Axis.horizontal это минимальные ширины.
/// Для Axis.vertical это минимальные высоты.
///
/// [onWeightsChanged] — callback, который вызывается при изменении весов.
///
/// [dividerThickness] — толщина разделителя и область попадания по нему.
///
/// [dividerBuilder] — позволяет задать собственный внешний вид разделителя.
class SplitView extends StatefulWidget {
  const SplitView({
    super.key,
    required this.axis,
    required this.children,
    this.weights,
    this.initialWeights,
    this.minSizes,
    this.onWeightsChanged,
    this.dividerThickness = 8.0,
    this.dividerBuilder,
  }) : assert(dividerThickness > 0, 'dividerThickness must be > 0');

  final Axis axis;
  final List<Widget> children;

  final List<double>? weights;
  final List<double>? initialWeights;
  final List<double>? minSizes;

  final ValueChanged<List<double>>? onWeightsChanged;

  final double dividerThickness;
  final SplitDividerBuilder? dividerBuilder;

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  late List<double> _weights;

  // Последние рассчитанные размеры используются во время перетаскивания.
  List<double> _lastSizes = const <double>[];
  List<double> _lastMins = const <double>[];
  double _lastRemaining = 0.0;

  @override
  void initState() {
    super.initState();
    _weights = _normalizeWeights(
      widget.initialWeights ?? widget.weights,
      widget.children.length,
    );
  }

  @override
  void didUpdateWidget(SplitView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Если количество детей изменилось и виджет неконтролируемый,
    // подгоняем внутренние веса под новое количество.
    if (widget.children.length != oldWidget.children.length &&
        widget.weights == null) {
      _weights = _normalizeWeights(_weights, widget.children.length);
    }
  }

  List<double> _effectiveWeights(int count) {
    final source = widget.weights ?? _weights;
    return _normalizeWeights(source, count);
  }

  void _applyWeights(List<double> nextWeights) {
    if (widget.weights == null) {
      setState(() {
        _weights = nextWeights;
      });
    }

    widget.onWeightsChanged?.call(nextWeights);
  }

  void _handleDrag(
    BuildContext context,
    int dividerIndex,
    double deltaPixels,
  ) {
    if (_lastSizes.length < dividerIndex + 2) return;
    if (_lastRemaining <= 0) return;

    final isHorizontal = widget.axis == Axis.horizontal;

    var delta = deltaPixels;

    // Для горизонтального split в RTL направление движения инвертируется.
    if (isHorizontal) {
      final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
      if (direction == TextDirection.rtl) {
        delta = -delta;
      }
    }

    final first = _lastSizes[dividerIndex];
    final second = _lastSizes[dividerIndex + 1];

    final combined = first + second;

    final minFirst = _lastMins[dividerIndex];
    final minSecond = _lastMins[dividerIndex + 1];

    final maxFirst = combined - minSecond;

    // Если места недостаточно, менять размер нельзя.
    if (maxFirst <= minFirst) return;

    var newFirst = first + delta;
    newFirst = newFirst.clamp(minFirst, maxFirst).toDouble();

    final deltaSize = newFirst - first;
    if (deltaSize == 0) return;

    // remainingSpace — это свободное место после вычета минимальных размеров.
    // Размер панели считается как:
    // minSize + remainingSpace * weight
    // Поэтому:
    // deltaWeight = deltaSize / remainingSpace
    final deltaWeight = deltaSize / _lastRemaining;

    final weights = List<double>.from(
      _effectiveWeights(_lastSizes.length),
    );

    weights[dividerIndex] += deltaWeight;
    weights[dividerIndex + 1] -= deltaWeight;

    // Защита от отрицательных значений из-за ошибок округления.
    for (var i = 0; i < weights.length; i++) {
      if (weights[i] < 0) {
        weights[i] = 0;
      }
    }

    _applyWeights(_normalizeWeights(weights, weights.length));
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;

    if (count == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorizontal = widget.axis == Axis.horizontal;

        final total = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;

        // SplitView требует ограниченную основную ось.
        // Не помещай горизонтальный SplitView внутрь горизонтального
        // SingleChildScrollView/ListView без фиксированной ширины.
        assert(
          total.isFinite,
          'SplitView requires finite main-axis constraints.',
        );

        if (!total.isFinite || total <= 0) {
          return const SizedBox.shrink();
        }

        final weights = _effectiveWeights(count);
        final mins = _effectiveMinSizes(count);

        final dividerSpace = widget.dividerThickness * (count - 1);
        final usable = math.max(0.0, total - dividerSpace);

        final minTotal = mins.fold<double>(
          0.0,
          (sum, value) => sum + value,
        );

        final remaining = math.max(0.0, usable - minTotal);

        final sizes = _resolveSizes(
          weights: weights,
          minSizes: mins,
          usable: usable,
          minTotal: minTotal,
          remaining: remaining,
        );

        // Сохраняем последние рассчитанные значения для drag-логики.
        _lastSizes = sizes;
        _lastMins = mins;
        _lastRemaining = remaining;

        final resultChildren = <Widget>[];

        for (var i = 0; i < count; i++) {
          if (i > 0) {
            resultChildren.add(
              _divider(
                context: context,
                dividerIndex: i - 1,
              ),
            );
          }

          resultChildren.add(
            SizedBox(
              width: isHorizontal ? sizes[i] : null,
              height: isHorizontal ? null : sizes[i],
              child: widget.children[i],
            ),
          );
        }

        if (isHorizontal) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: resultChildren,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: resultChildren,
        );
      },
    );
  }

  Widget _divider({
    required BuildContext context,
    required int dividerIndex,
  }) {
    final isHorizontal = widget.axis == Axis.horizontal;

    final defaultDivider = Container(
      color: Theme.of(context).dividerColor,
    );

    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: isHorizontal
            ? (details) {
                _handleDrag(
                  context,
                  dividerIndex,
                  details.delta.dx,
                );
              }
            : null,
        onVerticalDragUpdate: !isHorizontal
            ? (details) {
                _handleDrag(
                  context,
                  dividerIndex,
                  details.delta.dy,
                );
              }
            : null,
        child: SizedBox(
          width: isHorizontal ? widget.dividerThickness : null,
          height: isHorizontal ? null : widget.dividerThickness,
          child: widget.dividerBuilder == null
              ? defaultDivider
              : widget.dividerBuilder!(
                  context,
                  dividerIndex,
                  widget.axis,
                ),
        ),
      ),
    );
  }

  List<double> _effectiveMinSizes(int count) {
    return List<double>.generate(
      count,
      (index) {
        final minSizes = widget.minSizes;

        if (minSizes == null || index >= minSizes.length) {
          return 0.0;
        }

        return math.max(0.0, minSizes[index]);
      },
    );
  }

  static List<double> _normalizeWeights(
    List<double>? weights,
    int count,
  ) {
    if (count <= 0) {
      return const <double>[];
    }

    final result = List<double>.generate(
      count,
      (index) {
        if (weights == null || index >= weights.length) {
          return 0.0;
        }

        final value = weights[index];

        if (!value.isFinite || value <= 0) {
          return 0.0;
        }

        return value;
      },
    );

    final sum = result.fold<double>(
      0.0,
      (sum, value) => sum + value,
    );

    if (sum <= 0) {
      return List<double>.filled(count, 1.0 / count);
    }

    return result
        .map((value) => value / sum)
        .toList();
  }

  static List<double> _resolveSizes({
    required List<double> weights,
    required List<double> minSizes,
    required double usable,
    required double minTotal,
    required double remaining,
  }) {
    final count = weights.length;

    if (count == 0) {
      return const <double>[];
    }

    if (usable <= 0) {
      return List<double>.filled(count, 0.0);
    }

    // Если минимальные размеры больше доступного места,
    // масштабируем минимальные размеры, чтобы избежать overflow.
    if (minTotal >= usable) {
      if (minTotal <= 0) {
        return List<double>.filled(count, usable / count);
      }

      return minSizes
          .map((minSize) => minSize * usable / minTotal)
          .toList();
    }

    // Иначе распределяем свободное место согласно весам.
    //
    // Формула:
    // size[i] = minSize[i] + remaining * weights[i]
    return List<double>.generate(
      count,
      (index) {
        return minSizes[index] + remaining * weights[index];
      },
    );
  }
}