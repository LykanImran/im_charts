/// Defines how the trading chart adapts its layout and touch targets.
enum ChartLayoutMode {
  /// Automatically switches between [desktop] and [mobile] layouts
  /// based on available container or screen width (default breakpoint: 600px).
  auto,

  /// Forces full desktop trading layout with standard precision mouse hitboxes,
  /// 65px price axis, and full desktop toolbars.
  desktop,

  /// Forces streamlined mobile layout with enlarged touch handles (44px hit slop),
  /// compact price axis (52px), thumb-friendly telemetry, and mobile ergonomics.
  mobile,
}
