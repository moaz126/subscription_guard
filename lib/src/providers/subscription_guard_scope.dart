/// Provides the [SubscriptionGuardScope] InheritedWidget that exposes
/// subscription state to all descendant widgets in the tree.
///
/// This is the internal mechanism used by [SubscriptionGuardProvider] to
/// propagate tier, trial, and configuration data down the widget tree.
/// Developers can access it directly via [SubscriptionGuardScope.of] for
/// programmatic tier checks.
library;

import 'package:flutter/widgets.dart';

import '../models/guard_behavior.dart';
import '../models/tier.dart';
import '../models/tier_config.dart';
import '../models/trial_info.dart';

/// An [InheritedWidget] that sits in the widget tree and exposes subscription
/// state to all descendant widgets.
///
/// Holds the current [SubscriptionConfig], resolved [Tier], [TrialInfo],
/// default guard behavior, and optional callback hooks.
///
/// Typically not constructed directly — instead, wrap your app with
/// [SubscriptionGuardProvider], which manages state and builds this scope
/// internally.
///
/// Access the nearest scope via [SubscriptionGuardScope.of] or
/// [SubscriptionGuardScope.maybeOf].
///
/// Example:
/// ```dart
/// final scope = SubscriptionGuardScope.of(context);
/// if (scope.hasAccess('pro')) {
///   // show pro feature
/// }
/// ```
class SubscriptionGuardScope extends InheritedWidget {
  /// Creates a [SubscriptionGuardScope] with the given subscription state.
  ///
  /// This constructor is typically called by [SubscriptionGuardProvider]'s
  /// build method, not by application code directly.
  ///
  /// - [config]: The tier and feature configuration.
  /// - [currentTier]: The user's resolved [Tier] object.
  /// - [trialInfo]: The current trial state.
  /// - [defaultBehavior]: The app-wide default [GuardBehavior].
  /// - [defaultLockedBuilder]: An optional app-wide fallback widget builder
  ///   displayed when a feature is locked.
  /// - [onUpgradeRequested]: An optional callback invoked when the user
  ///   attempts to access a locked feature.
  /// - [onFeatureBlocked]: An optional analytics callback invoked when a
  ///   feature is blocked.
  /// - [child]: The widget subtree that can access this scope.
  const SubscriptionGuardScope({
    super.key,
    required this.config,
    required this.currentTier,
    required this.trialInfo,
    required this.defaultBehavior,
    this.defaultLockedBuilder,
    this.onUpgradeRequested,
    this.onFeatureBlocked,
    required super.child,
  });

  /// The tier and feature configuration defining all available tiers and
  /// their feature mappings.
  final SubscriptionConfig config;

  /// The user's current resolved [Tier] object.
  ///
  /// This is the actual [Tier] instance looked up from [config] based on
  /// the tier id string provided to [SubscriptionGuardProvider].
  final Tier currentTier;

  /// The current trial or grace period state.
  ///
  /// Defaults to [TrialInfo.none] when no trial is active.
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
  /// and the user's [currentTier].
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

  /// Returns the nearest [SubscriptionGuardScope] from the given [context].
  ///
  /// Throws a [FlutterError] with a helpful message if no scope is found
  /// in the widget tree.
  ///
  /// Example:
  /// ```dart
  /// final scope = SubscriptionGuardScope.of(context);
  /// ```
  static SubscriptionGuardScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No SubscriptionGuardProvider found in widget tree.'),
        ErrorDescription(
          'Did you forget to wrap your app with SubscriptionGuardProvider?',
        ),
        ErrorHint(
          'Ensure that a SubscriptionGuardProvider is an ancestor of the '
          'widget that called SubscriptionGuardScope.of(context).',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scope;
  }

  /// Returns the nearest [SubscriptionGuardScope] from the given [context],
  /// or `null` if none is found.
  ///
  /// Use this when you want to gracefully handle the absence of a provider
  /// rather than throwing an error.
  ///
  /// Example:
  /// ```dart
  /// final scope = SubscriptionGuardScope.maybeOf(context);
  /// if (scope != null) {
  ///   // use scope
  /// }
  /// ```
  static SubscriptionGuardScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SubscriptionGuardScope>();
  }

  /// Returns `true` if the [currentTier] level is greater than or equal to
  /// the tier identified by [tierId].
  ///
  /// Throws a [StateError] if [tierId] is not found in [config].
  ///
  /// Example:
  /// ```dart
  /// final scope = SubscriptionGuardScope.of(context);
  /// if (scope.hasAccess('pro')) { /* ... */ }
  /// ```
  bool hasAccess(String tierId) {
    return config.canAccess(currentTier.id, tierId);
  }

  /// Returns `true` if the [currentTier] has access to the feature
  /// identified by [featureId].
  ///
  /// Looks up the required tier for the feature in [config] and checks
  /// whether the [currentTier] level meets or exceeds it. Returns `true`
  /// if the feature is not mapped to any tier (unmapped features are
  /// considered accessible to all).
  ///
  /// Example:
  /// ```dart
  /// final scope = SubscriptionGuardScope.of(context);
  /// if (scope.hasFeatureAccess('export_pdf')) { /* ... */ }
  /// ```
  bool hasFeatureAccess(String featureId) {
    final requiredTierId = config.getRequiredTierForFeature(featureId);
    if (requiredTierId == null) return true;
    return config.canAccess(currentTier.id, requiredTierId);
  }

  /// Invokes the [onUpgradeRequested] callback, if set, with the [Tier]
  /// identified by [tierId].
  ///
  /// Throws a [StateError] if [tierId] is not found in [config].
  ///
  /// Example:
  /// ```dart
  /// scope.requestUpgrade('premium');
  /// ```
  void requestUpgrade(String tierId) {
    if (onUpgradeRequested != null) {
      final tier = config.getTierById(tierId);
      onUpgradeRequested!(tier);
    }
  }

  /// Invokes the [onFeatureBlocked] callback, if set, with the given
  /// [featureId] and the [Tier] identified by [requiredTierId].
  ///
  /// Throws a [StateError] if [requiredTierId] is not found in [config].
  ///
  /// Example:
  /// ```dart
  /// scope.reportBlocked(featureId: 'export_pdf', requiredTierId: 'pro');
  /// ```
  void reportBlocked({String? featureId, required String requiredTierId}) {
    if (onFeatureBlocked != null) {
      final requiredTier = config.getTierById(requiredTierId);
      onFeatureBlocked!(featureId, requiredTier, currentTier);
    }
  }

  /// Returns all feature ids accessible at the [currentTier] level.
  ///
  /// This includes features assigned to the current tier **and** all
  /// features assigned to lower tiers.
  List<String> get accessibleFeatures {
    return config.getAccessibleFeatures(currentTier.id);
  }

  /// Whether the user is currently in an active trial period.
  ///
  /// Delegates to [TrialInfo.isActive], which checks both the trial flag
  /// and expiration date.
  bool get isTrialing => trialInfo.isActive;

  /// Returns `true` if any of the tracked subscription state has changed,
  /// causing dependent widgets to rebuild.
  ///
  /// Checks [currentTier], [trialInfo], and [config] for changes.
  @override
  bool updateShouldNotify(covariant SubscriptionGuardScope oldWidget) {
    return currentTier != oldWidget.currentTier ||
        trialInfo != oldWidget.trialInfo ||
        config != oldWidget.config;
  }
}
