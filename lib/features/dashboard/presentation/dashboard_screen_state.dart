import 'package:life_os/features/dashboard/domain/dashboard_card_item.dart';

sealed class DashboardScreenState {
  const DashboardScreenState();

  T when<T>({
    required T Function() initial,
    required T Function() loading,
    required T Function(List<DashboardCardItem> items) loaded,
    required T Function(String message) error,
  }) {
    return switch (this) {
      DashboardScreenInitial() => initial(),
      DashboardScreenLoading() => loading(),
      DashboardScreenLoaded(:final items) => loaded(items),
      DashboardScreenError(:final message) => error(message),
    };
  }

  T maybeWhen<T>({
    T Function()? initial,
    T Function()? loading,
    T Function(List<DashboardCardItem> items)? loaded,
    T Function(String message)? error,
    required T Function() orElse,
  }) {
    return switch (this) {
      DashboardScreenInitial() => initial != null ? initial() : orElse(),
      DashboardScreenLoading() => loading != null ? loading() : orElse(),
      DashboardScreenLoaded(:final items) =>
        loaded != null ? loaded(items) : orElse(),
      DashboardScreenError(:final message) =>
        error != null ? error(message) : orElse(),
    };
  }
}

class DashboardScreenInitial extends DashboardScreenState {
  const DashboardScreenInitial();
}

class DashboardScreenLoading extends DashboardScreenState {
  const DashboardScreenLoading();
}

class DashboardScreenLoaded extends DashboardScreenState {
  final List<DashboardCardItem> items;

  const DashboardScreenLoaded(this.items);
}

class DashboardScreenError extends DashboardScreenState {
  final String message;

  const DashboardScreenError(this.message);
}
