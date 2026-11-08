import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior({this.fadeColor});
  final Color? fadeColor;

  @override
  bool shouldNotify(covariant AppScrollBehavior oldDelegate) =>
      oldDelegate.fadeColor != fadeColor;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final controller = details.controller;
    if (controller == null || controller is PageController) return child;
    final reduceMotion =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        (MediaQuery.maybeAccessibleNavigationOf(context) ?? false);
    return ScrollEdgeFade(
      controller: controller,
      direction: details.direction,
      fadeColor: fadeColor,
      child: reduceMotion
          ? child
          : StretchingOverscrollIndicator(
              axisDirection: details.direction,
              clipBehavior: details.decorationClipBehavior ?? Clip.hardEdge,
              child: child,
            ),
    );
  }
}

class ScrollEdgeFade extends StatefulWidget {
  const ScrollEdgeFade({
    super.key,
    required this.controller,
    required this.direction,
    required this.child,
    this.fadeColor,
  });
  final ScrollController controller;
  final AxisDirection direction;
  final Widget child;
  final Color? fadeColor;
  @override
  State<ScrollEdgeFade> createState() => _ScrollEdgeFadeState();
}

class _ScrollEdgeFadeState extends State<ScrollEdgeFade> {
  static const _fadeExtent = 20.0;
  double _before = 0;
  double _after = 0;
  bool _queued = false;
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(ScrollEdgeFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      _position?.removeListener(_changed);
      _position = null;
      widget.controller.addListener(_changed);
      _before = 0;
      _after = 0;
      _queueUpdate();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _position?.removeListener(_changed);
    super.dispose();
  }

  void _queueUpdate() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _changed();
    });
  }

  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _queueUpdate();
      return;
    }
    final positions = widget.controller.positions;
    var before = 0.0;
    var after = 0.0;
    final ownPosition = _position;
    final position = ownPosition != null && positions.contains(ownPosition)
        ? ownPosition
        : (positions.length == 1 ? positions.single : null);
    if (position != null) {
      if (position.hasPixels && position.hasContentDimensions) {
        before = (position.extentBefore / _fadeExtent).clamp(0, 1).toDouble();
        after = (position.extentAfter / _fadeExtent).clamp(0, 1).toDouble();
      }
    }
    if (before == _before && after == _after) return;
    setState(() {
      _before = before;
      _after = after;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vertical = axisDirectionToAxis(widget.direction) == Axis.vertical;
    final reverse = axisDirectionIsReversed(widget.direction);
    final leading = reverse ? _after : _before;
    final trailing = reverse ? _before : _after;
    Color shade(double opacity) => Colors.black.withValues(alpha: opacity);
    final fadeColor = widget.fadeColor;
    if (fadeColor != null) {
      return NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: ClipRect(
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final extent = vertical
                          ? constraints.maxHeight
                          : constraints.maxWidth;
                      final stop = extent <= 0
                          ? 0.0
                          : math.min(_fadeExtent / extent, .25);
                      Color tint(double opacity) =>
                          fadeColor.withValues(alpha: opacity);
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: vertical
                                ? Alignment.topCenter
                                : Alignment.centerLeft,
                            end: vertical
                                ? Alignment.bottomCenter
                                : Alignment.centerRight,
                            colors: [
                              tint(leading),
                              tint(leading * .5),
                              tint(0),
                              tint(0),
                              tint(trailing * .5),
                              tint(trailing),
                            ],
                            stops: [
                              0,
                              stop * .5,
                              stop,
                              1 - stop,
                              1 - stop * .5,
                              1,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final extent = vertical ? bounds.height : bounds.width;
          final stop = extent <= 0 ? 0.0 : math.min(_fadeExtent / extent, .25);
          return LinearGradient(
            begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
            end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
            colors: [
              shade(1 - leading),
              shade(1 - leading * .5),
              Colors.black,
              Colors.black,
              shade(1 - trailing * .5),
              shade(1 - trailing),
            ],
            stops: [0, stop * .5, stop, 1 - stop, 1 - stop * .5, 1],
          ).createShader(bounds);
        },
        child: widget.child,
      ),
    );
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      final position = Scrollable.maybeOf(notification.context)?.position;
      if (position != null &&
          position != _position &&
          widget.controller.positions.contains(position)) {
        _position?.removeListener(_changed);
        _position = position;
        position.addListener(_changed);
      }
      _changed();
    }
    return false;
  }
}
