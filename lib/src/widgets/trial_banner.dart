/// Provides the [TrialBanner] widget that displays trial status and a
/// countdown of remaining days.
///
/// Automatically shows or hides based on trial state from the provider.
library;

import 'package:flutter/material.dart';

import '../models/trial_info.dart';
import '../providers/subscription_guard_scope.dart';

/// A banner widget that displays the user's trial status and a countdown of
/// remaining days.
///
/// Reads trial state from [SubscriptionGuardScope] and automatically shows
/// or hides based on whether the user is trialing. When the trial is nearing
/// expiration (within [urgentThreshold] days), the banner switches to an
/// urgent visual style.
///
/// Basic usage — shows "X days remaining in your trial":
/// ```dart
/// TrialBanner()
/// ```
///
/// Custom builder for full control:
/// ```dart
/// TrialBanner(
///   builder: (context, trialInfo) {
///     return Text('${trialInfo.daysRemaining} days left!');
///   },
/// )
/// ```
///
/// With tap handler:
/// ```dart
/// TrialBanner(
///   onTap: () => showUpgradeDialog(),
/// )
/// ```
///
/// See also:
///
/// - [TrialInfo], the model class providing trial state data.
/// - [SubscriptionGuardScope], which exposes the [TrialInfo] read by this
///   widget.
/// - [SubscriptionGuardProvider], where trial state is configured.
class TrialBanner extends StatelessWidget {
  /// Creates a [TrialBanner] that displays trial status from the nearest
  /// [SubscriptionGuardScope].
  ///
  /// Parameters:
  /// - [builder]: An optional custom builder for full control over the
  ///   banner content. When provided, all default UI is bypassed.
  /// - [onTap]: An optional callback invoked when the banner is tapped
  ///   (e.g., to show an upgrade dialog).
  /// - [showWhenNotTrialing]: If `false` (default) and the user is not
  ///   trialing, the widget returns [SizedBox.shrink].
  /// - [urgentThreshold]: Number of remaining days at or below which the
  ///   banner uses the urgent/warning style. Defaults to `3`.
  /// - [backgroundColor]: Background color for the normal state. Defaults
  ///   to the theme's `colorScheme.primaryContainer`.
  /// - [urgentBackgroundColor]: Background color for the urgent state.
  ///   Defaults to the theme's `colorScheme.errorContainer`.
  /// - [padding]: Inner padding of the banner. Defaults to
  ///   `EdgeInsets.symmetric(horizontal: 16, vertical: 10)`.
  /// - [borderRadius]: Border radius of the banner container. Defaults to
  ///   `BorderRadius.circular(8)`.
  /// - [margin]: Outer margin around the banner. Defaults to
  ///   `EdgeInsets.symmetric(horizontal: 16, vertical: 8)`.
  const TrialBanner({
    super.key,
    this.builder,
    this.onTap,
    this.showWhenNotTrialing = false,
    this.urgentThreshold = 3,
    this.backgroundColor,
    this.urgentBackgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  /// An optional custom builder for full control over the banner content.
  ///
  /// When provided, all default UI logic is bypassed and the builder is
  /// called with the current [BuildContext] and [TrialInfo].
  ///
  /// Example:
  /// ```dart
  /// TrialBanner(
  ///   builder: (context, trialInfo) {
  ///     return Text('${trialInfo.daysRemaining} days left!');
  ///   },
  /// )
  /// ```
  final Widget Function(BuildContext context, TrialInfo trialInfo)? builder;

  /// An optional callback invoked when the banner is tapped.
  ///
  /// Commonly used to navigate to an upgrade screen or show a paywall
  /// dialog.
  final VoidCallback? onTap;

  /// Whether to show the banner when the user is not trialing.
  ///
  /// When `false` (default), the widget returns [SizedBox.shrink] if
  /// the user has no active or expired trial. Set to `true` to always
  /// display the banner (e.g., to show a "no trial" state).
  final bool showWhenNotTrialing;

  /// The number of remaining days at or below which the banner uses
  /// its urgent/warning style.
  ///
  /// Defaults to `3`.
  final int urgentThreshold;

  /// The background color for the normal (non-urgent) state.
  ///
  /// Defaults to the theme's `colorScheme.primaryContainer`.
  final Color? backgroundColor;

  /// The background color for the urgent state (when remaining days are
  /// at or below [urgentThreshold]).
  ///
  /// Defaults to the theme's `colorScheme.errorContainer`.
  final Color? urgentBackgroundColor;

  /// Inner padding of the banner container.
  ///
  /// Defaults to `EdgeInsets.symmetric(horizontal: 16, vertical: 10)`.
  final EdgeInsetsGeometry padding;

  /// Border radius of the banner container.
  ///
  /// Defaults to `BorderRadius.circular(8)`.
  final BorderRadius borderRadius;

  /// Outer margin around the banner container.
  ///
  /// Defaults to `EdgeInsets.symmetric(horizontal: 16, vertical: 8)`.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scope = SubscriptionGuardScope.of(context);
    final trialInfo = scope.trialInfo;

    // If a custom builder is provided, delegate entirely to it.
    if (builder != null) {
      return builder!(context, trialInfo);
    }

    // If not trialing and we shouldn't show when not trialing, hide.
    if (!trialInfo.isTrialing && !showWhenNotTrialing) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isExpired = trialInfo.isExpired;
    final daysRemaining = trialInfo.daysRemaining;
    final isUrgent =
        !isExpired && daysRemaining != null && daysRemaining <= urgentThreshold;

    // Determine visual state.
    final _BannerState bannerState;
    if (isExpired) {
      bannerState = _BannerState.expired;
    } else if (isUrgent) {
      bannerState = _BannerState.urgent;
    } else {
      bannerState = _BannerState.normal;
    }

    // Resolve background color.
    final Color resolvedBackgroundColor;
    switch (bannerState) {
      case _BannerState.expired:
      case _BannerState.urgent:
        resolvedBackgroundColor =
            urgentBackgroundColor ?? theme.colorScheme.errorContainer;
      case _BannerState.normal:
        resolvedBackgroundColor =
            backgroundColor ?? theme.colorScheme.primaryContainer;
    }

    // Resolve icon.
    final IconData resolvedIcon;
    switch (bannerState) {
      case _BannerState.expired:
        resolvedIcon = Icons.error_outline;
      case _BannerState.urgent:
        resolvedIcon = Icons.warning_amber_rounded;
      case _BannerState.normal:
        resolvedIcon = Icons.info_outline;
    }

    // Resolve messages.
    final String mainMessage;
    final String subtitleMessage;
    switch (bannerState) {
      case _BannerState.expired:
        mainMessage = 'Your trial has ended';
        subtitleMessage = 'Upgrade now to continue using premium features';
      case _BannerState.urgent:
        final dayWord = daysRemaining == 1 ? 'day' : 'days';
        mainMessage = 'Only $daysRemaining $dayWord left in your trial!';
        subtitleMessage = 'Upgrade to keep access to all features';
      case _BannerState.normal:
        if (daysRemaining == null) {
          mainMessage = "You're currently on a trial plan";
          subtitleMessage = 'Upgrade to keep access to all features';
        } else {
          final dayWord = daysRemaining == 1 ? 'day' : 'days';
          mainMessage = '$daysRemaining $dayWord remaining in your trial';
          subtitleMessage = 'Upgrade to keep access to all features';
        }
    }

    // Resolve text colors from the background.
    final Color iconColor;
    final Color mainTextColor;
    final Color subtitleColor;
    switch (bannerState) {
      case _BannerState.expired:
      case _BannerState.urgent:
        iconColor = theme.colorScheme.onErrorContainer;
        mainTextColor = theme.colorScheme.onErrorContainer;
        subtitleColor =
            theme.colorScheme.onErrorContainer.withValues(alpha: 0.7);
      case _BannerState.normal:
        iconColor = theme.colorScheme.onPrimaryContainer;
        mainTextColor = theme.colorScheme.onPrimaryContainer;
        subtitleColor =
            theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7);
    }

    final bannerContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedBackgroundColor,
        borderRadius: borderRadius,
      ),
      child: Row(
        children: [
          Icon(resolvedIcon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mainMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: mainTextColor,
                  ),
                ),
                Text(
                  subtitleMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: iconColor),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: bannerContent,
      );
    }

    return bannerContent;
  }
}

/// Internal enum representing the visual state of the trial banner.
enum _BannerState {
  /// Trial is active and not near expiration.
  normal,

  /// Trial is active but nearing expiration.
  urgent,

  /// Trial has expired.
  expired,
}
