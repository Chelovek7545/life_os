/// Explicit interaction policy. Scroll is delegated to scrollables; zoom has
/// priority while Ctrl/Meta is held or a scale gesture is active. Creation is
/// a long press on touch and direct drawing on desktop; wheel/trackpad remain
/// dedicated to scrolling and zooming.
class CalendarGesturePolicy {
  const CalendarGesturePolicy({
    this.desktopCreateRequiresShift = false,
    this.longPressDelay = const Duration(milliseconds: 350),
    this.minimumEventDuration = const Duration(minutes: 15),
  });

  final bool desktopCreateRequiresShift;
  final Duration longPressDelay;
  final Duration minimumEventDuration;
}
