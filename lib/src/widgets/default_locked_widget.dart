/// Provides the [DefaultLockedWidget], the built-in fallback UI shown when a
/// feature is locked behind a higher subscription tier.
///
/// This widget is used automatically by [SubscriptionGuard] when no custom
/// `lockedBuilder` is provided at either the widget or provider level.
/// Developers can also use it standalone or extend it.
library;

import 'package:flutter/material.dart';

import '../models/tier.dart';

/// The built-in fallback UI displayed when a feature is locked behind a
/// higher subscription tier.
///
/// Displays a professional locked state with a lock icon, text explaining
/// which tier is required, and an optional upgrade button.
///
/// Supports two layout modes:
/// - **Normal** (default): A centered column with icon, message, and optional
///   upgrade button. Suitable for larger areas.
/// - **Compact**: A single-line row with a small icon and message text.
///   Suitable for use inside lists or constrained spaces.
///
/// All colors and text styles are derived from [Theme.of(context)], ensuring
/// proper appearance in both light and dark themes.
///
/// Example:
/// ```dart
/// DefaultLockedWidget(
///   requiredTier: Tier(id: 'pro', level: 1, label: 'Pro'),
///   currentTier: Tier(id: 'free', level: 0, label: 'Free'),
///   onUpgradePressed: () => showPaywall(),
/// )
/// ```
///
/// Compact mode:
/// ```dart
/// DefaultLockedWidget(
///   requiredTier: proTier,
///   currentTier: freeTier,
///   compact: true,
/// )
/// ```
class DefaultLockedWidget extends StatelessWidget {
  /// Creates a [DefaultLockedWidget] showing a locked state for the given tiers.
  ///
  /// Required parameters:
  /// - [requiredTier]: The [Tier] needed to unlock the feature.
  /// - [currentTier]: The user's current [Tier].
  ///
  /// Optional parameters:
  /// - [onUpgradePressed]: Callback when the upgrade button is tapped.
  ///   If `null`, the upgrade button is hidden.
  /// - [message]: Custom message override. Defaults to
  ///   `"Upgrade to {requiredTier.label} to unlock this feature"`.
  /// - [icon]: The icon to display. Defaults to [Icons.lock_outline].
  /// - [iconSize]: The size of the icon. Defaults to `32.0`.
  /// - [iconColor]: The color of the icon. Defaults to the theme's
  ///   `disabledColor`.
  /// - [compact]: When `true`, shows a minimal single-line layout.
  ///   Defaults to `false`.
  const DefaultLockedWidget({
    super.key,
    required this.requiredTier,
    required this.currentTier,
    this.onUpgradePressed,
    this.message,
    this.icon = Icons.lock_outline,
    this.iconSize = 32.0,
    this.iconColor,
    this.compact = false,
    this.height,
  });

  /// The subscription tier required to unlock the guarded feature.
  final Tier requiredTier;

  /// The user's current subscription tier.
  final Tier currentTier;

  /// An optional callback invoked when the upgrade button is tapped.
  ///
  /// If `null`, the upgrade button is not displayed.
  final VoidCallback? onUpgradePressed;

  /// An optional custom message to display.
  ///
  /// When `null`, defaults to:
  /// `"Upgrade to {requiredTier.label} to unlock this feature"`.
  final String? message;

  /// The icon displayed in the locked state.
  ///
  /// Defaults to [Icons.lock_outline].
  final IconData icon;

  /// The size of the lock icon.
  ///
  /// Defaults to `32.0`. In compact mode, the icon is rendered at half
  /// this size.
  final double iconSize;

  /// The color of the lock icon.
  ///
  /// Defaults to [ThemeData.disabledColor] from the current theme.
  final Color? iconColor;

  /// Whether to use a compact single-line layout.
  ///
  /// When `true`, displays a row with a small icon and message text
  /// (no upgrade button). Useful inside lists or small spaces.
  ///
  /// Defaults to `false`.
  final bool compact;

  /// An optional fixed height for the locked widget.
  ///
  /// When provided, the widget is constrained to exactly this height.
  /// When `null` (the default), a minimum height of `120.0` is applied
  /// so the icon, message, and upgrade button always fit without overflow.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedIconColor = iconColor ?? theme.disabledColor;
    final resolvedMessage =
        message ?? 'Upgrade to ${requiredTier.label} to unlock this feature';

    if (compact) {
      return _buildCompact(context, theme, resolvedIconColor, resolvedMessage);
    }

    return _buildNormal(context, theme, resolvedIconColor, resolvedMessage);
  }

  Widget _buildCompact(
    BuildContext context,
    ThemeData theme,
    Color resolvedIconColor,
    String resolvedMessage,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize / 2,
            color: resolvedIconColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              resolvedMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.disabledColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormal(
    BuildContext context,
    ThemeData theme,
    Color resolvedIconColor,
    String resolvedMessage,
  ) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: resolvedIconColor,
            ),
            const SizedBox(height: 8),
            Text(
              resolvedMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.disabledColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (onUpgradePressed != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onUpgradePressed,
                child: Text('Upgrade to ${requiredTier.label}'),
              ),
            ],
          ],
        ),
      ),
    );

    if (height != null) {
      return SizedBox(height: height, child: content);
    }

    return content;
  }
}
