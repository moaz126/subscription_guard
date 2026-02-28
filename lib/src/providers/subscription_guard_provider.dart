/// Provides [SubscriptionGuardProvider], the public-facing StatefulWidget that
/// developers wrap their app with to inject subscription state into the tree.
///
/// This is the sole entry point for configuring tiers, trial info, and
/// callbacks — no global singletons are used.
library;

import 'package:flutter/widgets.dart';

import '../models/guard_behavior.dart';
import '../models/tier.dart';
import '../models/tier_config.dart';
import '../models/trial_info.dart';
import 'subscription_guard_scope.dart';

/// A [StatefulWidget] that manages subscription state and provides it to all
/// descendant widgets via [SubscriptionGuardScope].
///
/// Wrap your app (or a subtree) with this widget to enable tier-based feature
/// gating throughout the tree. This is the **only** way to inject subscription
/// state — no global singletons are involved.
///
/// The [currentTier] string is resolved to an actual [Tier] object from
/// [config] internally. When the parent rebuilds with a new [currentTier],
/// all `SubscriptionGuard` widgets below automatically rebuild.
///
/// Example:
/// ```dart
/// SubscriptionGuardProvider(
///   config: SubscriptionConfig(
///     tiers: [
///       Tier(id: 'free', level: 0, label: 'Free'),
///       Tier(id: 'pro', level: 1, label: 'Pro'),
///       Tier(id: 'premium', level: 2, label: 'Premium'),
///     ],
///     features: {
///       'advanced_stats': 'pro',
///       'export_pdf': 'pro',
///       'team_management': 'premium',
///     },
///   ),
///   currentTier: 'free',
///   onUpgradeRequested: (requiredTier) {
///     showPaywall(requiredTier);
///   },
///   onFeatureBlocked: (featureId, requiredTier, currentTier) {
///     analytics.log('feature_blocked', {'feature': featureId});
///   },
///   child: MyApp(),
/// )
/// ```
///
/// See also:
///
/// - [SubscriptionGuardScope], the [InheritedWidget] that propagates state.
/// - [SubscriptionConfig], the tier and feature configuration.
/// - [SubscriptionGuard], the widget used to gate individual features.
/// - [TrialInfo], for trial/grace period state.
class SubscriptionGuardProvider extends StatefulWidget {
  /// Creates a [SubscriptionGuardProvider] with the given configuration and
  /// state.
  ///
  /// Required parameters:
  /// - [config]: The [SubscriptionConfig] defining all tiers and feature
  ///   mappings.
  /// - [currentTier]: The id string of the user's current tier. Must match
  ///   a tier id in [config].
  /// - [child]: The widget subtree that will have access to subscription
  ///   state.
  ///
  /// Optional parameters:
  /// - [trialInfo]: Current trial state. Defaults to [TrialInfo.none].
  /// - [defaultBehavior]: App-wide default [GuardBehavior]. Defaults to
  ///   [GuardBehavior.replace].
  /// - [defaultLockedBuilder]: An optional app-wide fallback widget builder
  ///   for locked features.
  /// - [onUpgradeRequested]: An optional callback invoked when the user
  ///   tries to access a locked feature.
  /// - [onFeatureBlocked]: An optional analytics callback invoked when a
  ///   feature is blocked.
  const SubscriptionGuardProvider({
    super.key,
    required this.config,
    required this.currentTier,
    this.trialInfo = const TrialInfo.none(),
    this.defaultBehavior = GuardBehavior.replace,
    this.defaultLockedBuilder,
    this.onUpgradeRequested,
    this.onFeatureBlocked,
    required this.child,
  });

  /// The tier and feature configuration defining all available tiers and
  /// their feature mappings.
  final SubscriptionConfig config;

  /// The id string of the user's current subscription tier.
  ///
  /// Must correspond to a [Tier.id] in [config]. If this id is not found,
  /// an [ArgumentError] is thrown with a helpful message listing the
  /// available tier ids.
  final String currentTier;

  /// The current trial or grace period state.
  ///
  /// Defaults to [TrialInfo.none], indicating no active trial.
  final TrialInfo trialInfo;

  /// The app-wide default [GuardBehavior] used by `SubscriptionGuard`
  /// widgets that do not specify their own behavior.
  ///
  /// Defaults to [GuardBehavior.replace].
  final GuardBehavior defaultBehavior;

  /// An optional app-wide fallback widget builder displayed when a feature
  /// is locked and no widget-level `lockedBuilder` is provided.
  ///
  /// Receives the [BuildContext], the [Tier] required to access the feature,
  /// and the user's current [Tier].
  final Widget Function(
    BuildContext context,
    Tier requiredTier,
    Tier currentTier,
  )? defaultLockedBuilder;

  /// An optional callback invoked when the user attempts to access a locked
  /// feature (e.g., to show a paywall or upgrade prompt).
  ///
  /// Receives the [Tier] required to unlock the feature.
  final void Function(Tier requiredTier)? onUpgradeRequested;

  /// An optional analytics callback invoked when a feature is blocked.
  ///
  /// Receives the optional feature id, the [Tier] required, and the user's
  /// current [Tier].
  final void Function(
    String? featureId,
    Tier requiredTier,
    Tier currentTier,
  )? onFeatureBlocked;

  /// The widget subtree that will have access to subscription state via
  /// [SubscriptionGuardScope].
  final Widget child;

  /// Returns the nearest [SubscriptionGuardScope] from the given [context].
  ///
  /// This is a convenience method that delegates to
  /// [SubscriptionGuardScope.of].
  ///
  /// Throws a [FlutterError] if no [SubscriptionGuardProvider] is found
  /// in the widget tree.
  ///
  /// Example:
  /// ```dart
  /// final scope = SubscriptionGuardProvider.of(context);
  /// if (scope.hasAccess('pro')) { /* ... */ }
  /// ```
  static SubscriptionGuardScope of(BuildContext context) {
    return SubscriptionGuardScope.of(context);
  }

  @override
  State<SubscriptionGuardProvider> createState() =>
      _SubscriptionGuardProviderState();
}

class _SubscriptionGuardProviderState extends State<SubscriptionGuardProvider> {
  /// The resolved [Tier] object for the current tier id string.
  late Tier _resolvedTier;

  @override
  void initState() {
    super.initState();
    _resolvedTier = _resolveTier(widget.currentTier, widget.config);
  }

  @override
  void didUpdateWidget(covariant SubscriptionGuardProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTier != oldWidget.currentTier ||
        widget.config != oldWidget.config) {
      _resolvedTier = _resolveTier(widget.currentTier, widget.config);
    }
  }

  /// Resolves a tier id string to an actual [Tier] object from [config].
  ///
  /// Throws an [ArgumentError] with a helpful message if the tier id is not
  /// found, listing all available tier ids.
  Tier _resolveTier(String tierId, SubscriptionConfig config) {
    final tier = config.findTierById(tierId);
    if (tier == null) {
      final availableIds = config.tiers.map((t) => t.id).join(', ');
      throw ArgumentError(
        "Tier '$tierId' not found in config. "
        'Available tiers: $availableIds',
      );
    }
    return tier;
  }

  @override
  Widget build(BuildContext context) {
    return SubscriptionGuardScope(
      config: widget.config,
      currentTier: _resolvedTier,
      trialInfo: widget.trialInfo,
      defaultBehavior: widget.defaultBehavior,
      defaultLockedBuilder: widget.defaultLockedBuilder,
      onUpgradeRequested: widget.onUpgradeRequested,
      onFeatureBlocked: widget.onFeatureBlocked,
      child: widget.child,
    );
  }
}
