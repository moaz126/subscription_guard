/// Defines the [GuardBehavior] enum used to control how locked features
/// are presented to users who lack the required subscription tier.
library;

/// Defines how a locked feature should behave when the user's tier is
/// insufficient.
///
/// Used by the `SubscriptionGuard` widget to determine what to render when
/// the current subscription tier does not meet the required tier for a
/// feature.
///
/// The default behavior is [replace], which substitutes the child with a
/// locked placeholder widget.
///
/// Example:
/// ```dart
/// SubscriptionGuard(
///   requiredTier: 'pro',
///   behavior: GuardBehavior.blur,
///   child: PremiumWidget(),
/// )
/// ```
enum GuardBehavior {
  /// Completely removes the widget from the widget tree.
  ///
  /// When active, the guarded child is replaced with `SizedBox.shrink()`,
  /// effectively making it invisible and taking up no space.
  hide,

  /// Shows the widget but makes it non-interactive and visually dimmed.
  ///
  /// The child is wrapped in an [IgnorePointer] and [Opacity] widget,
  /// rendering it visible but greyed out and unresponsive to user input.
  disable,

  /// Replaces the child with a locked placeholder widget.
  ///
  /// Uses the `lockedBuilder` if provided, or falls back to a default
  /// locked widget that typically shows a lock icon and upgrade prompt.
  ///
  /// This is the **default** behavior.
  replace,

  /// Shows the child with a blur effect and a lock overlay on top.
  ///
  /// The original child is rendered but obscured by a blur filter, with
  /// a lock icon or overlay displayed on top to indicate the feature is
  /// locked.
  blur;

  /// Returns a human-readable description of this behavior.
  ///
  /// Useful for debugging, logging, or displaying behavior information
  /// in a settings UI.
  String get description {
    switch (this) {
      case GuardBehavior.hide:
        return 'Completely removes the widget from the tree, showing nothing.';
      case GuardBehavior.disable:
        return 'Shows the widget greyed out and non-interactive.';
      case GuardBehavior.replace:
        return 'Replaces the widget with a locked placeholder.';
      case GuardBehavior.blur:
        return 'Shows the widget blurred with a lock overlay on top.';
    }
  }
}
