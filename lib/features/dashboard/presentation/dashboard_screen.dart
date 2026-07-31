import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/features/dashboard/domain/dashboard_item.dart';
import 'package:life_os/features/dashboard/domain/dashboard_widget_type.dart';
import 'package:life_os/features/dashboard/presentation/components/grid_background.dart';
import 'package:life_os/features/dashboard/presentation/components/widget_container.dart';
import 'package:life_os/features/dashboard/presentation/components/widget_picker_panel.dart';
import 'package:life_os/features/dashboard/data/dashboard_widgets_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardWidgetsRepository _repo =
      DependencyContainer().dashboardWidgetsRepository;

  bool _isEditing = false;
  List<DashboardItem> _items = [];
  final int _totalColumns = 12;
  final double _cellHeight = 100.0;
  final double _spacing = 12.0;

  double _cellWidth = 0;
  final GlobalKey _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.loadWidgets();
    if (items.isEmpty) {
      await _addDefaults();
    } else {
      setState(() => _items = items);
    }
  }

  Future<void> _addDefaults() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _items = [
      DashboardItem(id: 'dft_${now}_0', x: 0, y: 0, w: 8, h: 3, type: DashboardWidgetType.tasks),
      DashboardItem(id: 'dft_${now}_1', x: 8, y: 0, w: 4, h: 2, type: DashboardWidgetType.timer),
      DashboardItem(id: 'dft_${now}_2', x: 8, y: 2, w: 4, h: 3, type: DashboardWidgetType.habits),
      DashboardItem(id: 'dft_${now}_3', x: 0, y: 3, w: 8, h: 2, type: DashboardWidgetType.calendar),
    ];
    await _repo.saveAll(_items);
  }

  Future<void> _saveAll() async {
    await _repo.saveAll(_items);
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
    int maxR = 4;
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
    _saveAll();
    setState(() {});
  }

  void _showWidgetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => WidgetPickerPanel(
        onWidgetSelected: (type) {
          final maxY = _items.isEmpty ? 0 : _items.map((i) => i.y + i.h).reduce((a, b) => a > b ? a : b);
          final item = DashboardItem(
            id: '',
            x: 0,
            y: maxY,
            w: type.defaultW,
            h: type.defaultH,
            type: type,
          );
          _repo.addWidget(item);
          setState(() => _items.add(item));
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
                physics: _isEditing
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                child: SizedBox(
                  height: boardHeight,
                  child: Stack(
                    key: _gridKey,
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
    final left = _spacing + item.x * (_cellWidth + _spacing);
    final top = _spacing + item.y * (_cellHeight + _spacing);
    final width = item.w * _cellWidth + (item.w - 1) * _spacing;
    final height = item.h * _cellHeight + (item.h - 1) * _spacing;

    Widget child = DashboardItemWidget(
      item: item,
      isEditing: _isEditing,
      cellWidth: _cellWidth,
      cellHeight: _cellHeight,
      spacing: _spacing,
      onTap: (_) {
        setState(() => _items.removeWhere((i) => i.id == item.id));
      },
    );

    if (_isEditing) {
      child = Draggable<DashboardItem>(
        data: item,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.7,
            child: SizedBox(
              width: width,
              height: height,
              child: DashboardItemWidget(
                item: item,
                isEditing: true,
                cellWidth: _cellWidth,
                cellHeight: _cellHeight,
                spacing: _spacing,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.2,
          child: DashboardItemWidget(
            item: item,
            isEditing: true,
            cellWidth: _cellWidth,
            cellHeight: _cellHeight,
            spacing: _spacing,
          ),
        ),
        dragAnchorStrategy: (_, _, position) {
          final gridBox =
              _gridKey.currentContext?.findRenderObject() as RenderBox?;
          final stepX = _cellWidth + _spacing;
          final stepY = _cellHeight + _spacing;
          final anchor = Offset(
            _spacing + item.x * stepX,
            _spacing + item.y * stepY,
          );
          if (gridBox == null) return position;
          return position - gridBox.localToGlobal(anchor);
        },
        onDragEnd: (details) {
          final gridBox =
              _gridKey.currentContext?.findRenderObject() as RenderBox?;
          final gridTopLeft =
              gridBox?.localToGlobal(Offset.zero) ?? Offset.zero;
          final stepX = _cellWidth + _spacing;
          final stepY = _cellHeight + _spacing;
          final delta = details.offset -
              gridTopLeft -
              Offset(_spacing + item.x * stepX, _spacing + item.y * stepY);
          final newX = (item.x + (delta.dx / stepX).round())
              .clamp(0, _totalColumns - item.w);
          final newY =
              (item.y + (delta.dy / stepY).round()).clamp(0, 50);
          if (!_hasCollision(newX, newY, item.w, item.h, item.id)) {
            setState(() {
              item.x = newX;
              item.y = newY;
            });
          }
        },
        child: child,
      );
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: width,
      height: height,
      child: child,
    );
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
