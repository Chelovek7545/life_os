import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// Коллапсируемая шторка: зона перетаскивания, «прилипание» к снаппоинтам
/// и анимированная высота.
///
/// Высоты задаются списком [snapPoints] (по возрастанию) — число снаппоинтов
/// равно длине списка. Содержимое передаётся через [bodyBuilder], которому
/// достаются прогресс раскрытия (0..1 внутри текущего сегмента) и индекс
/// нижнего снаппоинта этого сегмента. Шапка — отдельный виджет [header],
/// поэтому шторку можно переиспользовать с любым содержимым.
class CollapsibleSheet extends StatefulWidget {
  const CollapsibleSheet({
    super.key,
    required this.snapPoints,
    required this.header,
    required this.bodyBuilder,
    this.initialHeight,
    this.forceExpanded = false,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
    this.scrollableBody = true,
    this.onVisibilityChanged,
  });

  /// Высоты снаппоинтов по возрастанию: первый — минимум (видна только
  /// шапка), последний — полностью развёрнутая шторка.
  final List<double> snapPoints;

  /// Стартовая высота (по умолчанию [snapPoints]`[1]`, при N=1 — максимум).
  final double? initialHeight;

  /// Если true — шторка всегда полностью развёрнута, без перетаскивания.
  final bool forceExpanded;

  /// Шапка шторки (зона перетаскивания + кнопки).
  final Widget header;

  /// Содержимое шторки.
  ///
  /// [progress] — прогресс 0..1 внутри сегмента между [snapPoints]`[snapIndex]`
  /// и следующей точкой (на максимуме — 1.0). [snapIndex] — индекс нижнего
  /// снаппоинта текущего сегмента (на максимуме — последний индекс).
  final Widget Function(double progress, int snapIndex) bodyBuilder;

  final EdgeInsetsGeometry contentPadding;

  /// Если false — содержимое не оборачивается в SingleChildScrollView и
  /// занимает всю доступную высоту. Нужно, когда содержимое само управляет
  /// скроллом (например, TabBarView), а не скроллится как сплошной блок.
  final bool scrollableBody;

  /// Вызывается при изменении видимости (false = свёрнута до минимума).
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<CollapsibleSheet> createState() => _CollapsibleSheetState();
}

class _CollapsibleSheetState extends State<CollapsibleSheet> {
  // Текущая высота шторки
  late double _currentHeight;

  List<double> get _snapPoints => widget.snapPoints;
  double get _minHeight => _snapPoints.first;
  double get _maxHeight => _snapPoints.last;

  static bool _isSortedAscending(List<double> list) {
    for (var i = 1; i < list.length; i++) {
      if (list[i] < list[i - 1]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    assert(_snapPoints.length >= 1, 'snapPoints must not be empty');
    assert(_isSortedAscending(_snapPoints), 'snapPoints must be sorted');

    if (widget.forceExpanded) {
      _currentHeight = _maxHeight;
    } else {
      final fallback = _snapPoints.length >= 2 ? _snapPoints[1] : _maxHeight;
      final initial = widget.initialHeight ?? fallback;
      _currentHeight = initial.clamp(_minHeight, _maxHeight);
    }
  }

  /// Индекс нижнего снаппоинта сегмента, в котором находится шторка
  /// (на максимуме — последний индекс списка).
  int _currentSnapIndex() {
    for (var i = 0; i < _snapPoints.length - 1; i++) {
      if (_currentHeight < _snapPoints[i + 1]) return i;
    }
    return _snapPoints.length - 1;
  }

  /// Прогресс 0..1 внутри сегмента с нижней точкой [index].
  double _segmentProgress(int index) {
    if (index >= _snapPoints.length - 1) return 1.0;
    final denom = _snapPoints[index + 1] - _snapPoints[index];
    if (denom <= 0) return 1.0;
    return ((_currentHeight - _snapPoints[index]) / denom).clamp(0.0, 1.0);
  }

  // Метод плавного «прилипания» к снаппоинтам при завершении жеста
  void _snapToPosition(double velocity) {
    final int targetIndex;
    if (velocity > 400) {
      // Быстрый свайп вниз -> на один снаппоинт вниз от текущей позиции
      var index = _snapPoints.length - 1;
      while (index > 0 && _snapPoints[index] >= _currentHeight) {
        index--;
      }
      targetIndex = index;
    } else if (velocity < -400) {
      // Быстрый свайп вверх -> на один снаппоинт вверх от текущей позиции
      var index = 0;
      while (index < _snapPoints.length - 1 &&
          _snapPoints[index] <= _currentHeight) {
        index++;
      }
      targetIndex = index;
    } else {
      // Зависит от того, к какому снаппоинту ближе
      var nearest = 0;
      for (var i = 1; i < _snapPoints.length; i++) {
        if ((_snapPoints[i] - _currentHeight).abs() <
            (_snapPoints[nearest] - _currentHeight).abs()) {
          nearest = i;
        }
      }
      targetIndex = nearest;
    }

    setState(() => _currentHeight = _snapPoints[targetIndex]);
    widget.onVisibilityChanged?.call(_currentHeight != _maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forceExpanded) {
      return _buildForceExpanded(context);
    }

    final snapIndex = _currentSnapIndex();
    final progress = _segmentProgress(snapIndex);

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 120,
        ), // Минимальная задержка для сглаживания ручного ввода
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: _currentHeight,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.borderGlass,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            // Динамический цвет: становится темнее при полном раскрытии
            color: Color.lerp(
              AppColors.surface,
              AppColors.surfaceDim,
              progress,
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.xxl),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ЗОНА ДЛЯ ПЕРЕТАСКИВАНИЯ (ХЭНДЛ)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  setState(() {
                    // Изменяем высоту в зависимости от движения пальца/курсора
                    // Движение вверх уменьшает Y, но увеличивает высоту
                    _currentHeight =
                        (_currentHeight - details.delta.dy).clamp(
                          _minHeight,
                          _maxHeight,
                        );
                  });
                },
                onVerticalDragEnd: (details) {
                  _snapToPosition(details.primaryVelocity ?? 0);
                },
                child: widget.header,
              ),

              // ТЕЛО ШТОРКИ
              Expanded(
                child: widget.scrollableBody
                    ? SingleChildScrollView(
                        physics: _currentHeight == _maxHeight
                            ? const BouncingScrollPhysics()
                            : const NeverScrollableScrollPhysics(), // Блокируем скролл контента, если шторка не на максимуме
                        padding: widget.contentPadding,
                        child: widget.bodyBuilder(progress, snapIndex, ),
                      )
                    : widget.bodyBuilder(progress, snapIndex, ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForceExpanded(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.borderGlass,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        color: AppColors.surfaceDim,
      ),
      child: Column(
        children: [
          widget.header,
          Expanded(
            child: widget.scrollableBody
                ? SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: widget.contentPadding,
                    child: widget.bodyBuilder(1.0, _snapPoints.length - 1, ),
                  )
                : widget.bodyBuilder(1.0, _snapPoints.length - 1, ),
          ),
        ],
      ),
    );
  }
}
