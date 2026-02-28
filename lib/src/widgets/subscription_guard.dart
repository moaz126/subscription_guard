/// Provides the [SubscriptionGuard] widget, the core gating widget that
/// conditionally shows, hides, disables, blurs, or replaces its child
/// based on the user's subscription tier.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/guard_behavior.dart';
import '../models/tier.dart';
import '../providers/subscription_guard_scope.dart';
import 'default_locked_widget.dart';

/// Declaratively gate any widget behind a subscription tier.
///
/// Reads the current subscription state from [SubscriptionGuardScope] and
/// determines whether the [child] should be shown, hidden, disabled, blurred,
/// or replaced based on the user's tier and the configured [GuardBehavior].
///
/// There are three ways to construct a [SubscriptionGuard]:
///
/// **Tier-based (hierarchy)** — the default constructor checks whether the
/// user's tier level meets or exceeds the required tier:
/// ```dart
/// SubscriptionGuard(
///   requiredTier: 'pro',
///   child: AdvancedAnalyticsWidget(),
/// )
/// ```
///
/// **Feature-based** — looks up the required tier from the config's feature
/// map:
/// ```dart
/// SubscriptionGuard.feature(
///   featureId: 'export_pdf',
///   child: ExportButton(),
/// )
/// ```
///
/// **Allowed tiers (exact match)** — grants access only if the user's tier
/// id is in the provided list (not hierarchy-based):
/// ```dart
/// SubscriptionGuard.allowedTiers(
///   tierIds: ['pro', 'enterprise'],
///   child: TeamFeatureWidget(),
/// )
/// ```
///
/// Custom locked UI:
/// ```dart
/// SubscriptionGuard(
///   requiredTier: 'pro',
///   behavior: GuardBehavior.replace,
///   lockedBuilder: (context, requiredTier, currentTier) {
///     return MyCustomUpgradePrompt(tier: requiredTier);
///   },
///   child: AdvancedAnalyticsWidget(),
/// )
/// ```
class SubscriptionGuard extends StatelessWidget {
  /// Creates a [SubscriptionGuard] that gates [child] behind the tier
  /// identified by [requiredTier] using hierarchy-based access checks.
  ///
  /// The user's current tier level must be greater than or equal to the
  /// required tier's level for access to be granted.
  ///
  /// Parameters:
  /// - [requiredTier]: The minimum tier id needed to show [child].
  /// - [child]: The widget to display when access is granted.
  /// - [behavior]: Override the provider's default [GuardBehavior].
  ///   If `null`, falls back to the provider's [defaultBehavior].
  /// - [lockedBuilder]: Widget-level override for the locked UI.
  /// - [allowDuringTrial]: If `true` (default), trialing users with a
  ///   matching tier get access regardless of tier level.
  /// - [onBlocked]: Called when this guard blocks the user. Useful for
  ///   per-widget side effects like showing a snackbar.
  const SubscriptionGuard({
    super.key,
    required this.requiredTier,
    required this.child,
    this.behavior,
    this.lockedBuilder,
    this.allowDuringTrial = true,
    this.onBlocked,
  })  : featureId = null,
        tierIds = null,
        _mode = _GuardMode.tier;

  /// Creates a [SubscriptionGuard] that gates [child] behind a feature
  /// defined in [SubscriptionConfig.features].
  ///
  /// The [featureId] is resolved to a required tier id via
  /// [SubscriptionConfig.getRequiredTierForFeature]. If the feature is not
  /// found, a [FlutterError] is thrown with a helpful message.
  ///
  /// Parameters:
  /// - [featureId]: The feature identifier to look up in the config.
  /// - [child]: The widget to display when access is granted.
  /// - [behavior]: Override the provider's default [GuardBehavior].
  /// - [lockedBuilder]: Widget-level override for the locked UI.
  /// - [allowDuringTrial]: If `true` (default), trialing users get access.
  /// - [onBlocked]: Called when this guard blocks the user.
  ///
  /// Example:
  /// ```dart
  /// SubscriptionGuard.feature(
  ///   featureId: 'export_pdf',
  ///   child: ExportButton(),
  /// )
  /// ```
  const SubscriptionGuard.feature({
    super.key,
    required this.featureId,
    required this.child,
    this.behavior,
    this.lockedBuilder,
    this.allowDuringTrial = true,
    this.onBlocked,
  })  : requiredTier = null,
        tierIds = null,
        _mode = _GuardMode.feature;

  /// Creates a [SubscriptionGuard] that grants access only if the user's
  /// current tier id is in the [tierIds] list.
  ///
  /// Unlike the default constructor, this does **not** use hierarchy-based
  /// access — it checks for an exact match of the tier id.
  ///
  /// Parameters:
  /// - [tierIds]: Specific tier ids that can access [child].
  /// - [child]: The widget to display when access is granted.
  /// - [behavior]: Override the provider's default [GuardBehavior].
  /// - [lockedBuilder]: Widget-level override for the locked UI.
  /// - [allowDuringTrial]: If `true` (default), trialing users get access.
  /// - [onBlocked]: Called when this guard blocks the user.
  ///
  /// Example:
  /// ```dart
  /// SubscriptionGuard.allowedTiers(
  ///   tierIds: ['pro', 'enterprise'],
  ///   child: TeamFeatureWidget(),
  /// )
  /// ```
  const SubscriptionGuard.allowedTiers({
    super.key,
    required this.tierIds,
    required this.child,
    this.behavior,
    this.lockedBuilder,
    this.allowDuringTrial = true,
    this.onBlocked,
  })  : requiredTier = null,
        featureId = null,
        _mode = _GuardMode.allowedTiers;

  /// The minimum tier id required for hierarchy-based access.
  ///
  /// Used by the default constructor. `null` for other constructors.
  final String? requiredTier;

  /// The feature id to look up in the config's feature map.
  ///
  /// Used by [SubscriptionGuard.feature]. `null` for other constructors.
  final String? featureId;

  /// The list of specific tier ids allowed access.
  ///
  /// Used by [SubscriptionGuard.allowedTiers]. `null` for other constructors.
  final List<String>? tierIds;

  /// The widget to display when the user has access.
  final Widget child;

  /// The guard behavior to apply when access is denied.
  ///
  /// If `null`, falls back to the provider's [defaultBehavior]
  /// (which defaults to [GuardBehavior.replace]).
  final GuardBehavior? behavior;

  /// An optional widget-level override for the locked UI.
  ///
  /// Takes priority over the provider-level `defaultLockedBuilder` and
  /// the built-in [DefaultLockedWidget].
  ///
  /// Receives the [BuildContext], the [Tier] required to unlock the feature,
  /// and the user's current [Tier].
  final Widget Function(
    BuildContext context,
    Tier requiredTier,
    Tier currentTier,
  )? lockedBuilder;

  /// Whether to grant access to trialing users.
  ///
  /// When `true` (default) and the user is currently in an active trial,
  /// access is granted regardless of tier level.
  final bool allowDuringTrial;

  /// An optional callback invoked when this guard blocks the user.
  ///
  /// Useful for per-widget side effects such as showing a snackbar.
  /// For analytics, prefer using the provider-level `onFeatureBlocked`
  /// callback instead.
  final VoidCallback? onBlocked;

  /// The internal mode determining which access check to use.
  final _GuardMode _mode;

  @override
  Widget build(BuildContext context) {
    final scope = SubscriptionGuardScope.of(context);

    // Step 1: Determine the resolved tier id for access checks.
    final String resolvedTierId;
    switch (_mode) {
      case _GuardMode.tier:
        resolvedTierId = requiredTier!;
      case _GuardMode.feature:
        final tierId = scope.config.getRequiredTierForFeature(featureId!);
        if (tierId == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              "Feature '${featureId!}' not found in "
              'SubscriptionConfig.features.',
            ),
            ErrorHint(
              'Did you forget to add it? Available features: '
              '${scope.config.features.keys.join(', ')}',
            ),
          ]);
        }
        resolvedTierId = tierId;
      case _GuardMode.allowedTiers:
        // For allowedTiers mode, access is checked differently below.
        // Use the lowest tier as a placeholder for the locked widget.
        resolvedTierId = scope.config.lowestTier.id;
    }

    // Step 2: Determine if user has access.
    bool hasAccess;
    switch (_mode) {
      case _GuardMode.tier:
      case _GuardMode.feature:
        hasAccess = scope.hasAccess(resolvedTierId);
      case _GuardMode.allowedTiers:
        hasAccess = tierIds!.contains(scope.currentTier.id);
    }

    // Grant access during trial if allowed.
    if (!hasAccess && allowDuringTrial && scope.isTrialing) {
      hasAccess = true;
    }

    // Step 3: If access granted, return child directly.
    if (hasAccess) {
      return child;
    }

    // Step 4: Access denied — handle blocked state.
    onBlocked?.call();

    // Report blocked for analytics.
    scope.reportBlocked(
      featureId: featureId,
      requiredTierId: resolvedTierId,
    );

    // Resolve the effective behavior.
    final effectiveBehavior = behavior ?? scope.defaultBehavior;

    // Resolve the required Tier object for locked builders.
    final Tier resolvedRequiredTier;
    switch (_mode) {
      case _GuardMode.allowedTiers:
        // For allowedTiers, use the highest tier from the allowed list
        // that exists in config, or fall back to the highest tier overall.
        resolvedRequiredTier =
            _resolveHighestAllowedTier(scope) ?? scope.config.highestTier;
      case _GuardMode.tier:
      case _GuardMode.feature:
        resolvedRequiredTier = scope.config.getTierById(resolvedTierId);
    }

    // Apply the behavior.
    return _applyBehavior(
      context,
      scope,
      effectiveBehavior,
      resolvedRequiredTier,
    );
  }

  /// Resolves the locked widget based on priority: widget-level lockedBuilder,
  /// provider-level defaultLockedBuilder, or built-in [DefaultLockedWidget].
  Widget _resolveLockedWidget(
    BuildContext context,
    SubscriptionGuardScope scope,
    Tier resolvedRequiredTier,
  ) {
    if (lockedBuilder != null) {
      return lockedBuilder!(context, resolvedRequiredTier, scope.currentTier);
    }

    if (scope.defaultLockedBuilder != null) {
      return scope.defaultLockedBuilder!(
        context,
        resolvedRequiredTier,
        scope.currentTier,
      );
    }

    return DefaultLockedWidget(
      requiredTier: resolvedRequiredTier,
      currentTier: scope.currentTier,
      onUpgradePressed: () => scope.requestUpgrade(resolvedRequiredTier.id),
    );
  }

  /// Applies the given [GuardBehavior] and returns the appropriate widget.
  Widget _applyBehavior(
    BuildContext context,
    SubscriptionGuardScope scope,
    GuardBehavior effectiveBehavior,
    Tier resolvedRequiredTier,
  ) {
    switch (effectiveBehavior) {
      case GuardBehavior.hide:
        return const SizedBox.shrink();

      case GuardBehavior.disable:
        return IgnorePointer(
          child: Opacity(
            opacity: 0.4,
            child: child,
          ),
        );

      case GuardBehavior.replace:
        return _resolveLockedWidget(context, scope, resolvedRequiredTier);

      case GuardBehavior.blur:
        final lockedOverlay =
            _resolveLockedWidget(context, scope, resolvedRequiredTier);
        return Stack(
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: child,
            ),
            Positioned.fill(
              child: Container(
                color: Theme.of(context)
                    .scaffoldBackgroundColor
                    .withValues(alpha: 0.3),
                child: lockedOverlay,
              ),
            ),
          ],
        );
    }
  }

  /// Finds the highest tier from [tierIds] that exists in the config.
  Tier? _resolveHighestAllowedTier(SubscriptionGuardScope scope) {
    Tier? highest;
    for (final id in tierIds!) {
      final tier = scope.config.findTierById(id);
      if (tier != null && (highest == null || tier.isHigherThan(highest))) {
        highest = tier;
      }
    }
    return highest;
  }
}

/// Internal enum to track which constructor was used.
enum _GuardMode {
  /// Default constructor — hierarchy-based tier access.
  tier,

  /// [SubscriptionGuard.feature] — feature-based access.
  feature,

  /// [SubscriptionGuard.allowedTiers] — exact tier id match.
  allowedTiers,
}
