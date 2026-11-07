import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/app_notifiacations.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.diContainer});
  final DependencyContainer diContainer;
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  StreamSubscription<PluginNotice>? _notices;
  @override
  void initState() {
    super.initState();
    _notices = widget.diContainer.ui.notices.listen((notice) {
      if (!mounted) return;
      AppNotification.show(
        context,
        message: notice.message,
        type: notice.isError ? ToastType.error : ToastType.info,
        alignment: Alignment.bottomCenter,
      );
    });
  }

  @override
  void dispose() {
    unawaited(_notices?.cancel());
    unawaited(
      widget.diContainer.dispose().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.diContainer.navigation,
    builder: (context, _) {
      final registry = widget.diContainer.ui;
      final navigation = widget.diContainer.navigation;
      final destinations = registry.screens;
      final index = destinations.indexWhere(
        (screen) => screen.id == navigation.selectedId,
      );
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      void select(int index) => navigation.open(destinations[index].id);
      return SafeArea(
        child: Scaffold(
          bottomNavigationBar: landscape || destinations.isEmpty
              ? null
              : SlidingNavBar(
                  destinations: destinations,
                  selectedIndex: index,
                  onTap: select,
                ),
          backgroundColor: AppColors.surfaceDim,
          resizeToAvoidBottomInset: navigation.resizeToAvoidBottomInset,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  if (landscape && destinations.isNotEmpty)
                    _LandscapeNavRail(
                      destinations: destinations,
                      selectedIndex: index,
                      onTap: select,
                      pluginActions: PluginActions(
                        registry: registry,
                        location: PluginActionLocation.navigationRail,
                      ),
                    ),
                  Expanded(child: PluginScreenDeck(navigation: navigation)),
                ],
              ),
              PluginPanelSlot(
                registry: registry,
                slot: 'app.overlays',
                layout: (_, panels) =>
                    Stack(fit: StackFit.expand, children: panels),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LandscapeNavRail extends StatelessWidget {
  const _LandscapeNavRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    required this.pluginActions,
  });
  final List<PluginScreenContribution> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Widget pluginActions;
  @override
  Widget build(BuildContext context) => Container(
    width: 80,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceDim,
      border: Border.all(color: AppColors.borderGlass),
    ),
    child: Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: destinations.length,
            itemBuilder: (context, index) => InkWell(
              key: ValueKey('navigation-rail:${destinations[index].id}'),
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 74.5,
                decoration: BoxDecoration(
                  color: selectedIndex == index
                      ? AppColors.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: selectedIndex == index
                        ? AppColors.borderGlass
                        : Colors.transparent,
                  ),
                ),
                child: _DestinationLabel(
                  destination: destinations[index],
                  selected: selectedIndex == index,
                ),
              ),
            ),
          ),
        ),
        pluginActions,
      ],
    ),
  );
}

class SlidingNavBar extends StatelessWidget {
  const SlidingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });
  final List<PluginScreenContribution> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth - 24,
          destinations.length * 76.0,
        );
        final itemWidth = width / destinations.length;
        return Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceDim,
            border: Border.all(color: AppColors.borderGlass),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: itemWidth * selectedIndex + itemWidth * .05,
                    top: 1,
                    bottom: 1,
                    width: itemWidth * .9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.borderGlass),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        SizedBox(
                          width: itemWidth,
                          child: InkWell(
                            key: ValueKey(
                              'navigation-bar:${destinations[i].id}',
                            ),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onTap(i),
                            child: _DestinationLabel(
                              destination: destinations[i],
                              selected: selectedIndex == i,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DestinationLabel extends StatelessWidget {
  const _DestinationLabel({required this.destination, required this.selected});
  final PluginScreenContribution destination;
  final bool selected;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutBack,
    scale: selected ? 1.05 : 1,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          destination.icon,
          size: 26,
          color: selected ? AppColors.primaryContainer : AppColors.onBackground,
          shadows: selected
              ? [const Shadow(color: Color(0x99FF4400), blurRadius: 15)]
              : null,
        ),
        const SizedBox(height: 2),
        Text(
          destination.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.codeLabel.copyWith(
            fontSize: 10,
            color: selected
                ? AppColors.primaryContainer
                : AppColors.onBackground,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 2.5,
            width: 20,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}
