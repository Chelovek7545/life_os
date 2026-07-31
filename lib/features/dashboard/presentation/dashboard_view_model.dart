import 'package:life_os/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:life_os/features/dashboard/domain/dashboard_item.dart';
import 'package:life_os/features/dashboard/domain/dashboard_widget_type.dart';
import 'package:rxdart/rxdart.dart';

class DashboardViewModel {
  final DashboardLayoutRepository _repository;

  DashboardViewModel(this._repository);

  final BehaviorSubject<List<DashboardItem>> _itemsController =
      BehaviorSubject<List<DashboardItem>>.seeded([]);
  Stream<List<DashboardItem>> get itemsStream => _itemsController.stream;
  List<DashboardItem> get items => _itemsController.value;

  Future<void> initialize() async {
    var items = await _repository.loadLayout();
    if (items == null) {
      items = _defaultItems();
      await _repository.saveLayout(items);
    }
    if (!_itemsController.isClosed) {
      _itemsController.add(items);
    }
  }

  Future<void> addWidget(DashboardWidgetType type) async {
    final current = _itemsController.value;
    final maxY =
        current.isEmpty ? 0 : current.map((i) => i.y + i.h).reduce((a, b) => a > b ? a : b);
    final item = DashboardItem(
      id: _repository.generateId(),
      x: 0,
      y: maxY,
      w: type.defaultW,
      h: type.defaultH,
      type: type,
    );
    _itemsController.add([...current, item]);
  }

  void removeWidget(String id) {
    _itemsController.add(
      List.of(_itemsController.value)..removeWhere((i) => i.id == id),
    );
  }

  void moveWidget(String id, int x, int y) {
    final items = List.of(_itemsController.value);
    for (final item in items) {
      if (item.id == id) {
        item.x = x;
        item.y = y;
        break;
      }
    }
    _itemsController.add(items);
  }

  void resizeWidget(String id, int w, int h) {
    final items = List.of(_itemsController.value);
    for (final item in items) {
      if (item.id == id) {
        item.w = w;
        item.h = h;
        break;
      }
    }
    _itemsController.add(items);
  }

  Future<void> commitLayout() {
    return _repository.saveLayout(_itemsController.value);
  }

  void dispose() {
    _itemsController.close();
  }

  List<DashboardItem> _defaultItems() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      DashboardItem(id: 'dft_${now}_0', x: 0, y: 0, w: 8, h: 3, type: DashboardWidgetType.tasks),
      DashboardItem(id: 'dft_${now}_1', x: 8, y: 0, w: 4, h: 2, type: DashboardWidgetType.timer),
      DashboardItem(id: 'dft_${now}_2', x: 8, y: 2, w: 4, h: 3, type: DashboardWidgetType.habits),
      DashboardItem(id: 'dft_${now}_3', x: 0, y: 3, w: 8, h: 2, type: DashboardWidgetType.calendar),
    ];
  }
}
