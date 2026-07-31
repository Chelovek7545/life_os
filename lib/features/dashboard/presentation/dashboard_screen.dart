import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_os/features/dashboard/domain/dashboard_item.dart';
import 'package:life_os/features/dashboard/presentation/components/grid_background.dart';
import 'package:life_os/features/dashboard/presentation/components/widget_container.dart';
import 'package:life_os/features/dashboard/presentation/components/widget_picker_panel.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_view_model.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardViewModel viewModel;
  const DashboardScreen({super.key, required this.viewModel});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isEditing = false;
  List<DashboardItem> _items = [];
  StreamSubscription<List<DashboardItem>>? _subscription;
  final int _totalColumns = 8;
  final int _totalRows = 4;
  final double _cellHeight = 100.0;
  final double _spacing = 12.0;

  double _cellWidth = 0;
  int? _dragPointerId;
  String? _draggingItemId;
  double? _dragStartCellX;
  double? _dragStartCellY;
  Offset? _dragStartGlobal;
  Offset _dragOffset = Offset.zero;
  int? _ghostX;
  int? _ghostY;
  double? _ghostW;
  double? _ghostH;
  String? _resizingItemId;
  Offset _resizeOffset = Offset.zero;
  int? _resizeStartW;
  int? _resizeStartH;

  @override
  void initState() {
    super.initState();
    _items = widget.viewModel.items;
    _subscription = widget.viewModel.itemsStream.listen((items) {
      if (mounted) setState(() => _items = items);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool _hasCollision(int x, int y, int w, int h, String ignoreId) {
    if (x < 0 || x + w > _totalColumns || y < 0) return true;
    for (final item in _items) {
      if (item.id == ignoreId) continue;
      final overlapX = x < item.x + item.w && x + w > item.x;
      final overlapY = y < item.y + item.h && y + h > item.y;
      if (overlapX && overlapY) return true;
    }
    return false;
  }

  int get _maxRows {
    int maxR = _totalRows;
    for (final item in _items) {
      if (item.y + item.h > maxR) maxR = item.y + item.h;
    }
    return maxR + 2;
  }

  void _enterEditMode() {
    setState(() => _isEditing = true);
  }

  void _exitEditMode() {
    _isEditing = false;
    widget.viewModel.commitLayout();
    setState(() {});
  }

  void _showWidgetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => WidgetPickerPanel(
        onWidgetSelected: (type) {
          widget.viewModel.addWidget(type);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isEditing)
            TextButton.icon(
              onPressed: _exitEditMode,
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
              label: const Text('Done',
                  style: TextStyle(color: Colors.greenAccent)),
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: _enterEditMode,
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _cellWidth =
              (constraints.maxWidth - (_spacing * (_totalColumns + 1))) /
                  _totalColumns;
          final boardHeight = _maxRows * (_cellHeight + _spacing) + _spacing;

          return Stack(
            children: [
              SingleChildScrollView(
                physics:  const BouncingScrollPhysics(),
                child: SizedBox(
                  height: boardHeight,
                  child: Stack(
                    children: [
                      if (_isEditing)
                        CustomPaint(
                          painter: GridBackgroundPainter(
                            columns: _totalColumns,
                            rows: _maxRows,
                            cellWidth: _cellWidth,
                            cellHeight: _cellHeight,
                            spacing: _spacing,
                          ),
                          size: Size.infinite,
                        ),
                      if (_isEditing &&
                          _draggingItemId != null &&
                          _ghostX != null &&
                          _ghostY != null &&
                          _ghostW != null &&
                          _ghostH != null)
                        Positioned(
                          left: _spacing + _ghostX! * (_cellWidth + _spacing),
                          top: _spacing + _ghostY! * (_cellHeight + _spacing),
                          width: _ghostW!,
                          height: _ghostH!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blueAccent.withValues(alpha: 0.6),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ..._items.map((item) => _buildItemWidget(item)),
                    ],
                  ),
                ),
              ),
              if (_isEditing)
                Positioned(
                  right: _spacing,
                  bottom: _spacing,
                  child: _AddWidgetFab(onTap: _showWidgetPicker),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemWidget(DashboardItem item) {
    final stepX = _cellWidth + _spacing;
    final stepY = _cellHeight + _spacing;
    final baseLeft = _spacing + item.x * stepX;
    final baseTop = _spacing + item.y * stepY;
    final width = item.w * _cellWidth + (item.w - 1) * _spacing;
    final height = item.h * _cellHeight + (item.h - 1) * _spacing;
    final isThisDragging = _draggingItemId == item.id;
    final isThisResizing = _resizingItemId == item.id;

    final left = isThisDragging ? baseLeft + _dragOffset.dx : baseLeft;
    final top = isThisDragging ? baseTop + _dragOffset.dy : baseTop;
    final displayWidth =
        isThisResizing ? (width + _resizeOffset.dx).clamp(_cellWidth, 1e9) : width;
    final displayHeight =
        isThisResizing ? (height + _resizeOffset.dy).clamp(_cellHeight, 1e9) : height;

    Widget child = DashboardItemWidget(
      item: item,
      isEditing: _isEditing,
      cellWidth: _cellWidth,
      cellHeight: _cellHeight,
      spacing: _spacing,
      onTap: (_) {
        widget.viewModel.removeWidget(item.id);
      },
      onResizeStart: () {
        setState(() {
          _resizingItemId = item.id;
          _resizeOffset = Offset.zero;
          _resizeStartW = item.w;
          _resizeStartH = item.h;
        });
      },
      onResizeUpdate: (delta) {
        setState(() => _resizeOffset = delta);
      },
      onResizeEnd: (delta) {
        final stepX = _cellWidth + _spacing;
        final stepY = _cellHeight + _spacing;
        final addedW = (delta.dx / stepX).round();
        final addedH = (delta.dy / stepY).round();
        widget.viewModel.resizeWidget(
          item.id,
          (_resizeStartW! + addedW).clamp(1, _totalColumns),
          (_resizeStartH! + addedH).clamp(1, 50),
        );
        setState(() {
          _resizingItemId = null;
          _resizeOffset = Offset.zero;
          _resizeStartW = null;
          _resizeStartH = null;
        });
      },
    );

    if (_isEditing) {
      child = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          final inResizeZone = event.localPosition.dx >= width - 32 &&
              event.localPosition.dy >= height - 32;
          final inDeleteZone = event.localPosition.dx >= width - 32 &&
              event.localPosition.dy <= 32;
          if (inResizeZone || inDeleteZone) return;
          _dragPointerId = event.pointer;
          _draggingItemId = item.id;
          _dragStartCellX = item.x.toDouble();
          _dragStartCellY = item.y.toDouble();
          _dragStartGlobal = event.position;
          _dragOffset = Offset.zero;
          _ghostX = item.x;
          _ghostY = item.y;
          _ghostW = width;
          _ghostH = height;
          setState(() {});
        },
        onPointerMove: (event) {
          if (event.pointer != _dragPointerId) return;
          final offset = event.position - _dragStartGlobal!;
          final calculatedX = (_dragStartCellX! + offset.dx / stepX)
              .round()
              .clamp(0, _totalColumns - item.w);
          final calculatedY =
              (_dragStartCellY! + offset.dy / stepY).round().clamp(0, 50);
          final moved = calculatedX != _ghostX || calculatedY != _ghostY;
          setState(() {
            _dragOffset = offset;
            if (moved &&
                !_hasCollision(
                    calculatedX, calculatedY, item.w, item.h, item.id)) {
              _ghostX = calculatedX;
              _ghostY = calculatedY;
              HapticFeedback.selectionClick();
            }
          });
        },
        onPointerUp: (_) => _endDrag(),
        onPointerCancel: (_) => _endDrag(),
        child: child,
      );
    }

    return AnimatedPositioned(
      key: ValueKey(item.id),
      duration: isThisDragging || isThisResizing
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: displayWidth,
      height: displayHeight,
      child: child,
    );
  }

  void _endDrag() {
    if (_dragPointerId == null) return;
    final draggingId = _draggingItemId;
    final ghostX = _ghostX;
    final ghostY = _ghostY;
    setState(() {
      if (draggingId != null && ghostX != null && ghostY != null) {
        widget.viewModel.moveWidget(draggingId, ghostX, ghostY);
      }
      _dragPointerId = null;
      _draggingItemId = null;
      _dragStartCellX = null;
      _dragStartCellY = null;
      _dragStartGlobal = null;
      _dragOffset = Offset.zero;
      _ghostX = null;
      _ghostY = null;
      _ghostW = null;
      _ghostH = null;
    });
  }
}

class _AddWidgetFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddWidgetFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.blueAccent.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}
