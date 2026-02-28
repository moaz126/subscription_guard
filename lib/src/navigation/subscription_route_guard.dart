/// Navigation guard utilities for protecting routes behind subscription tiers.
///
/// Provides multiple approaches for route protection:
///
/// - **GoRouter-compatible redirect functions** ([subscriptionRedirect] and
///   [subscriptionFeatureRedirect]) that work with GoRouter's `redirect`
///   parameter without this package depending on go_router.
/// - **Static utility methods** on [SubscriptionRouteGuard] for programmatic
///   access checks and guarded navigation with [Navigator].
/// - **[SubscriptionPageRoute]**, a [MaterialPageRoute] wrapper that
///   automatically guards based on tier.
///
/// > **Note:** This package does **not** depend on go_router. If you use the
/// > GoRouter redirect helpers, you must add go_router as a dependency in your
/// > own project's `pubspec.yaml`.
///
/// GoRouter usage:
/// ```dart
/// GoRoute(
///   path: '/analytics',
///   redirect: subscriptionRedirect(
///     requiredTier: 'pro',
///     redirectPath: '/upgrade',
///   ),
/// )
/// ```
///
/// GoRouter with feature-based guard:
/// ```dart
/// GoRoute(
///   path: '/export',
///   redirect: subscriptionFeatureRedirect(
///     featureId: 'export_pdf',
///     redirectPath: '/upgrade',
///   ),
/// )
/// ```
///
/// Manual navigation check:
/// ```dart
/// onTap: () {
///   final result = SubscriptionRouteGuard.checkAccess(
///     context,
///     requiredTier: 'pro',
///   );
///   if (result.hasAccess) {
///     Navigator.pushNamed(context, '/analytics');
///   } else {
///     showUpgradeDialog(result.requiredTier);
///   }
/// }
/// ```
///
/// Navigator push with built-in guard:
/// ```dart
/// SubscriptionRouteGuard.pushGuarded(
///   context,
///   requiredTier: 'pro',
///   route: MaterialPageRoute(builder: (_) => AnalyticsScreen()),
///   onBlocked: (requiredTier, currentTier) {
///     showPaywall(requiredTier);
///   },
/// );
/// ```
library;

import 'package:flutter/material.dart';

import '../models/tier.dart';
import '../providers/subscription_guard_scope.dart';
import '../widgets/default_locked_widget.dart';

// ---------------------------------------------------------------------------
// Part A: RouteAccessResult
// ---------------------------------------------------------------------------

/// Holds the result of a route or feature access check.
///
/// Returned by [SubscriptionRouteGuard.checkAccess] and
/// [SubscriptionRouteGuard.checkFeatureAccess] so callers can inspect the
/// outcome and decide how to proceed.
///
/// Example:
/// ```dart
/// final result = SubscriptionRouteGuard.checkAccess(
///   context,
///   requiredTier: 'pro',
/// );
/// if (result.hasAccess) {
///   Navigator.pushNamed(context, '/analytics');
/// } else {
///   print('Blocked — need ${result.requiredTier?.label}');
/// }
/// ```
class RouteAccessResult {
  /// Creates a [RouteAccessResult].
  ///
  /// - [hasAccess]: Whether access is granted.
  /// - [currentTier]: The user's current [Tier].
  /// - [requiredTier]: The tier that was required, or `null` if access was
  ///   granted without a specific tier check.
  /// - [isTrialing]: Whether the user is currently in an active trial.
  const RouteAccessResult({
    required this.hasAccess,
    required this.currentTier,
    this.requiredTier,
    required this.isTrialing,
  });

  /// Whether the user has access to the guarded route or feature.
  final bool hasAccess;

  /// The user's current subscription [Tier].
  final Tier currentTier;

  /// The [Tier] that was required to access the route, or `null` if no
  /// specific tier was checked.
  final Tier? requiredTier;

  /// Whether the user is currently in an active trial period.
  final bool isTrialing;

  /// Whether the user is blocked from accessing the route.
  ///
  /// Convenience getter — equivalent to `!hasAccess`.
  bool get isBlocked => !hasAccess;
}

// ---------------------------------------------------------------------------
// Part B: subscriptionRedirect (GoRouter-compatible, tier-based)
// ---------------------------------------------------------------------------

/// Returns a redirect function compatible with GoRouter's `redirect`
/// parameter that gates a route behind a subscription tier.
///
/// This is a **top-level function** so it can be used directly in GoRoute
/// configuration without class instantiation.
///
/// > **Important:** This package does **not** depend on go_router. The
/// > returned function accepts `dynamic state` as its second parameter to
/// > remain compatible without importing GoRouter types. You must add
/// > go_router as a dependency in your own project.
///
/// Parameters:
/// - [requiredTier]: The minimum tier id the user must have.
/// - [redirectPath]: The path to redirect to when access is denied
///   (e.g., `'/upgrade'`).
/// - [allowDuringTrial]: If `true` (default), trialing users are allowed
///   through.
/// - [redirectQueryParams]: Optional query parameters to append to
///   [redirectPath] when redirecting (e.g., `{'from': 'analytics'}`).
/// - [customRedirect]: An optional function for full control over the
///   redirect path. Receives the context, required tier, and current tier.
///   Return `null` to allow access, or a path string to redirect.
///
/// Example:
/// ```dart
/// GoRoute(
///   path: '/analytics',
///   redirect: subscriptionRedirect(
///     requiredTier: 'pro',
///     redirectPath: '/upgrade',
///     redirectQueryParams: {'from': 'analytics'},
///   ),
/// )
/// ```
String? Function(BuildContext context, dynamic state) subscriptionRedirect({
  required String requiredTier,
  required String redirectPath,
  bool allowDuringTrial = true,
  Map<String, String>? redirectQueryParams,
  String? Function(BuildContext context, Tier requiredTier, Tier currentTier)?
      customRedirect,
}) {
  return (BuildContext context, dynamic state) {
    final scope = SubscriptionGuardScope.of(context);

    final hasAccess = scope.hasAccess(requiredTier);

    if (!hasAccess && allowDuringTrial && scope.isTrialing) {
      return null;
    }

    if (hasAccess) {
      return null;
    }

    // Blocked.
    scope.reportBlocked(requiredTierId: requiredTier);

    final resolvedRequiredTier = scope.config.getTierById(requiredTier);

    if (customRedirect != null) {
      return customRedirect(context, resolvedRequiredTier, scope.currentTier);
    }

    return _buildRedirectPath(redirectPath, redirectQueryParams);
  };
}

// ---------------------------------------------------------------------------
// Part C: subscriptionFeatureRedirect (GoRouter-compatible, feature-based)
// ---------------------------------------------------------------------------

/// Returns a redirect function compatible with GoRouter's `redirect`
/// parameter that gates a route behind a feature defined in the
/// subscription config.
///
/// Resolves [featureId] to the required tier using
/// [SubscriptionConfig.getRequiredTierForFeature], then applies the same
/// logic as [subscriptionRedirect].
///
/// Throws a [StateError] if [featureId] is not found in the config.
///
/// > **Important:** This package does **not** depend on go_router. You must
/// > add go_router as a dependency in your own project.
///
/// Parameters:
/// - [featureId]: The feature identifier to look up in the config.
/// - [redirectPath]: The path to redirect to when access is denied.
/// - [allowDuringTrial]: If `true` (default), trialing users are allowed
///   through.
/// - [redirectQueryParams]: Optional query parameters to append to
///   [redirectPath].
/// - [customRedirect]: An optional function for full control over the
///   redirect path.
///
/// Example:
/// ```dart
/// GoRoute(
///   path: '/export',
///   redirect: subscriptionFeatureRedirect(
///     featureId: 'export_pdf',
///     redirectPath: '/upgrade',
///   ),
/// )
/// ```
String? Function(BuildContext context, dynamic state)
    subscriptionFeatureRedirect({
  required String featureId,
  required String redirectPath,
  bool allowDuringTrial = true,
  Map<String, String>? redirectQueryParams,
  String? Function(BuildContext context, Tier requiredTier, Tier currentTier)?
      customRedirect,
}) {
  return (BuildContext context, dynamic state) {
    final scope = SubscriptionGuardScope.of(context);

    final requiredTierId = scope.config.getRequiredTierForFeature(featureId);
    if (requiredTierId == null) {
      throw StateError(
        "Feature '$featureId' not found in SubscriptionConfig.features. "
        'Did you forget to add it? Available features: '
        '${scope.config.features.keys.join(', ')}',
      );
    }

    final hasAccess = scope.hasAccess(requiredTierId);

    if (!hasAccess && allowDuringTrial && scope.isTrialing) {
      return null;
    }

    if (hasAccess) {
      return null;
    }

    // Blocked.
    scope.reportBlocked(featureId: featureId, requiredTierId: requiredTierId);

    final resolvedRequiredTier = scope.config.getTierById(requiredTierId);

    if (customRedirect != null) {
      return customRedirect(context, resolvedRequiredTier, scope.currentTier);
    }

    return _buildRedirectPath(redirectPath, redirectQueryParams);
  };
}

// ---------------------------------------------------------------------------
// Part D: SubscriptionRouteGuard — Static utility class
// ---------------------------------------------------------------------------

/// A collection of static utility methods for programmatic route access
/// checks and guarded navigation.
///
/// This class cannot be instantiated — all methods are static.
///
/// Provides:
/// - [checkAccess] / [checkFeatureAccess] — return a [RouteAccessResult]
///   without navigating.
/// - [pushGuarded] / [pushNamedGuarded] / [pushFeatureGuarded] — navigate
///   only if the user has access, otherwise invoke a blocked callback.
///
/// Example:
/// ```dart
/// final result = SubscriptionRouteGuard.checkAccess(
///   context,
///   requiredTier: 'pro',
/// );
/// if (result.hasAccess) {
///   Navigator.pushNamed(context, '/pro-feature');
/// }
/// ```
abstract final class SubscriptionRouteGuard {
  // ------------------------------------------------------------------
  // Programmatic access checks
  // ------------------------------------------------------------------

  /// Checks whether the current user has access to the tier identified by
  /// [requiredTier] and returns a [RouteAccessResult].
  ///
  /// Does **not** navigate or redirect — the caller decides what to do
  /// with the result.
  ///
  /// Parameters:
  /// - [context]: A [BuildContext] that has a [SubscriptionGuardProvider]
  ///   ancestor.
  /// - [requiredTier]: The minimum tier id required.
  /// - [allowDuringTrial]: If `true` (default), trialing users are
  ///   considered to have access.
  ///
  /// Example:
  /// ```dart
  /// final result = SubscriptionRouteGuard.checkAccess(
  ///   context,
  ///   requiredTier: 'pro',
  /// );
  /// if (result.hasAccess) {
  ///   Navigator.pushNamed(context, '/analytics');
  /// } else {
  ///   showUpgradeDialog(result.requiredTier);
  /// }
  /// ```
  static RouteAccessResult checkAccess(
    BuildContext context, {
    required String requiredTier,
    bool allowDuringTrial = true,
  }) {
    final scope = SubscriptionGuardScope.of(context);
    var hasAccess = scope.hasAccess(requiredTier);

    if (!hasAccess && allowDuringTrial && scope.isTrialing) {
      hasAccess = true;
    }

    return RouteAccessResult(
      hasAccess: hasAccess,
      currentTier: scope.currentTier,
      requiredTier: scope.config.getTierById(requiredTier),
      isTrialing: scope.isTrialing,
    );
  }

  /// Checks whether the current user has access to the feature identified
  /// by [featureId] and returns a [RouteAccessResult].
  ///
  /// Resolves [featureId] to the required tier using the config's feature
  /// map. Throws a [StateError] if [featureId] is not found.
  ///
  /// Parameters:
  /// - [context]: A [BuildContext] with a [SubscriptionGuardProvider]
  ///   ancestor.
  /// - [featureId]: The feature identifier to look up.
  /// - [allowDuringTrial]: If `true` (default), trialing users have access.
  ///
  /// Example:
  /// ```dart
  /// final result = SubscriptionRouteGuard.checkFeatureAccess(
  ///   context,
  ///   featureId: 'export_pdf',
  /// );
  /// if (result.isBlocked) {
  ///   showPaywall(result.requiredTier);
  /// }
  /// ```
  static RouteAccessResult checkFeatureAccess(
    BuildContext context, {
    required String featureId,
    bool allowDuringTrial = true,
  }) {
    final scope = SubscriptionGuardScope.of(context);

    final requiredTierId = scope.config.getRequiredTierForFeature(featureId);
    if (requiredTierId == null) {
      throw StateError(
        "Feature '$featureId' not found in SubscriptionConfig.features. "
        'Did you forget to add it? Available features: '
        '${scope.config.features.keys.join(', ')}',
      );
    }

    return checkAccess(
      context,
      requiredTier: requiredTierId,
      allowDuringTrial: allowDuringTrial,
    );
  }

  // ------------------------------------------------------------------
  // Guarded navigation
  // ------------------------------------------------------------------

  /// Pushes [route] onto the navigator stack only if the user has access
  /// to the tier identified by [requiredTier].
  ///
  /// If the user is blocked:
  /// - Calls [onBlocked] with the required and current tiers (if provided).
  /// - If [requestUpgradeOnBlock] is `true` (default), invokes
  ///   [SubscriptionGuardScope.requestUpgrade].
  /// - Reports the block via [SubscriptionGuardScope.reportBlocked].
  /// - Returns `null`.
  ///
  /// Parameters:
  /// - [context]: A [BuildContext] with a [SubscriptionGuardProvider]
  ///   ancestor.
  /// - [requiredTier]: The minimum tier id required.
  /// - [route]: The [Route] to push when access is granted.
  /// - [onBlocked]: Optional callback when the user is blocked.
  /// - [allowDuringTrial]: If `true` (default), trialing users have access.
  /// - [requestUpgradeOnBlock]: If `true` (default), automatically requests
  ///   an upgrade when blocked.
  ///
  /// Returns the result of [Navigator.push] if access is granted, or `null`
  /// if blocked.
  ///
  /// Example:
  /// ```dart
  /// final result = await SubscriptionRouteGuard.pushGuarded(
  ///   context,
  ///   requiredTier: 'pro',
  ///   route: MaterialPageRoute(builder: (_) => AnalyticsScreen()),
  ///   onBlocked: (requiredTier, currentTier) {
  ///     showPaywall(requiredTier);
  ///   },
  /// );
  /// ```
  static Future<T?> pushGuarded<T>(
    BuildContext context, {
    required String requiredTier,
    required Route<T> route,
    void Function(Tier requiredTier, Tier currentTier)? onBlocked,
    bool allowDuringTrial = true,
    bool requestUpgradeOnBlock = true,
  }) async {
    final result = checkAccess(
      context,
      requiredTier: requiredTier,
      allowDuringTrial: allowDuringTrial,
    );

    if (result.hasAccess) {
      return Navigator.of(context).push(route);
    }

    // Blocked.
    final scope = SubscriptionGuardScope.of(context);
    onBlocked?.call(result.requiredTier!, result.currentTier);

    if (requestUpgradeOnBlock) {
      scope.requestUpgrade(requiredTier);
    }

    scope.reportBlocked(requiredTierId: requiredTier);

    return null;
  }

  /// Pushes a named route onto the navigator stack only if the user has
  /// access to the tier identified by [requiredTier].
  ///
  /// Behaves identically to [pushGuarded] but uses
  /// [Navigator.pushNamed] with [routeName] and optional [arguments].
  ///
  /// Parameters:
  /// - [context]: A [BuildContext] with a [SubscriptionGuardProvider]
  ///   ancestor.
  /// - [requiredTier]: The minimum tier id required.
  /// - [routeName]: The named route to push when access is granted.
  /// - [arguments]: Optional arguments to pass to the route.
  /// - [onBlocked]: Optional callback when the user is blocked.
  /// - [allowDuringTrial]: If `true` (default), trialing users have access.
  /// - [requestUpgradeOnBlock]: If `true` (default), automatically requests
  ///   an upgrade when blocked.
  ///
  /// Returns the result of [Navigator.pushNamed] if access is granted, or
  /// `null` if blocked.
  ///
  /// Example:
  /// ```dart
  /// await SubscriptionRouteGuard.pushNamedGuarded(
  ///   context,
  ///   requiredTier: 'pro',
  ///   routeName: '/analytics',
  ///   onBlocked: (requiredTier, currentTier) {
  ///     ScaffoldMessenger.of(context).showSnackBar(
  ///       SnackBar(content: Text('Upgrade to ${requiredTier.label}')),
  ///     );
  ///   },
  /// );
  /// ```
  static Future<T?> pushNamedGuarded<T>(
    BuildContext context, {
    required String requiredTier,
    required String routeName,
    Object? arguments,
    void Function(Tier requiredTier, Tier currentTier)? onBlocked,
    bool allowDuringTrial = true,
    bool requestUpgradeOnBlock = true,
  }) async {
    final result = checkAccess(
      context,
      requiredTier: requiredTier,
      allowDuringTrial: allowDuringTrial,
    );

    if (result.hasAccess) {
      return Navigator.of(context).pushNamed<T>(
        routeName,
        arguments: arguments,
      );
    }

    // Blocked.
    final scope = SubscriptionGuardScope.of(context);
    onBlocked?.call(result.requiredTier!, result.currentTier);

    if (requestUpgradeOnBlock) {
      scope.requestUpgrade(requiredTier);
    }

    scope.reportBlocked(requiredTierId: requiredTier);

    return null;
  }

  /// Pushes [route] onto the navigator stack only if the user has access
  /// to the feature identified by [featureId].
  ///
  /// Resolves [featureId] to the required tier using the config's feature
  /// map, then delegates to [pushGuarded]. Throws a [StateError] if
  /// [featureId] is not found.
  ///
  /// Parameters:
  /// - [context]: A [BuildContext] with a [SubscriptionGuardProvider]
  ///   ancestor.
  /// - [featureId]: The feature identifier to look up.
  /// - [route]: The [Route] to push when access is granted.
  /// - [onBlocked]: Optional callback when the user is blocked.
  /// - [allowDuringTrial]: If `true` (default), trialing users have access.
  /// - [requestUpgradeOnBlock]: If `true` (default), automatically requests
  ///   an upgrade when blocked.
  ///
  /// Example:
  /// ```dart
  /// await SubscriptionRouteGuard.pushFeatureGuarded(
  ///   context,
  ///   featureId: 'export_pdf',
  ///   route: MaterialPageRoute(builder: (_) => ExportScreen()),
  /// );
  /// ```
  static Future<T?> pushFeatureGuarded<T>(
    BuildContext context, {
    required String featureId,
    required Route<T> route,
    void Function(Tier requiredTier, Tier currentTier)? onBlocked,
    bool allowDuringTrial = true,
    bool requestUpgradeOnBlock = true,
  }) {
    final scope = SubscriptionGuardScope.of(context);

    final requiredTierId = scope.config.getRequiredTierForFeature(featureId);
    if (requiredTierId == null) {
      throw StateError(
        "Feature '$featureId' not found in SubscriptionConfig.features. "
        'Did you forget to add it? Available features: '
        '${scope.config.features.keys.join(', ')}',
      );
    }

    return pushGuarded<T>(
      context,
      requiredTier: requiredTierId,
      route: route,
      onBlocked: onBlocked,
      allowDuringTrial: allowDuringTrial,
      requestUpgradeOnBlock: requestUpgradeOnBlock,
    );
  }
}

// ---------------------------------------------------------------------------
// Part E: SubscriptionPageRoute
// ---------------------------------------------------------------------------

/// A [MaterialPageRoute] that automatically guards its content behind a
/// subscription tier.
///
/// When pushed onto the navigator, the route checks the user's tier. If
/// access is granted, the original [builder] is called. If blocked, it
/// displays a [blockedBuilder] (or a default [Scaffold] with a
/// [DefaultLockedWidget]) and optionally invokes an [onBlocked] callback.
///
/// > **Note:** Unlike [SubscriptionRouteGuard.pushGuarded], this route
/// > always pushes — it just changes what is displayed based on access.
/// > Use [pushGuarded] if you want to prevent the push entirely.
///
/// Example:
/// ```dart
/// Navigator.of(context).push(
///   SubscriptionPageRoute(
///     requiredTier: 'pro',
///     builder: (context) => ProScreen(),
///     onBlocked: (required, current) => showPaywall(required),
///   ),
/// );
/// ```
class SubscriptionPageRoute<T> extends MaterialPageRoute<T> {
  /// Creates a [SubscriptionPageRoute] that guards its content behind the
  /// tier identified by [requiredTier].
  ///
  /// Parameters:
  /// - [requiredTier]: The minimum tier id required to see the page.
  /// - [builder]: The widget builder for when access is granted.
  /// - [blockedBuilder]: An optional widget builder for when access is
  ///   denied. Receives the [BuildContext], required [Tier], and current
  ///   [Tier]. If `null`, a default [Scaffold] with [DefaultLockedWidget]
  ///   is shown.
  /// - [onBlocked]: An optional callback invoked when the user is blocked.
  /// - [allowDuringTrial]: If `true` (default), trialing users have access.
  /// - [settings]: Route settings forwarded to [MaterialPageRoute].
  /// - [fullscreenDialog]: Whether the route is a fullscreen dialog.
  ///   Forwarded to [MaterialPageRoute].
  /// - [maintainState]: Whether the route should be maintained in memory.
  ///   Forwarded to [MaterialPageRoute].
  SubscriptionPageRoute({
    required this.requiredTier,
    required WidgetBuilder builder,
    this.blockedBuilder,
    this.onBlocked,
    this.allowDuringTrial = true,
    super.settings,
    super.fullscreenDialog,
    super.maintainState,
  }) : super(
          builder: (BuildContext context) {
            final scope = SubscriptionGuardScope.of(context);
            var hasAccess = scope.hasAccess(requiredTier);

            if (!hasAccess && allowDuringTrial && scope.isTrialing) {
              hasAccess = true;
            }

            if (hasAccess) {
              return builder(context);
            }

            // Blocked.
            final resolvedRequiredTier = scope.config.getTierById(requiredTier);

            onBlocked?.call(resolvedRequiredTier, scope.currentTier);
            scope.reportBlocked(requiredTierId: requiredTier);

            if (blockedBuilder != null) {
              return blockedBuilder(
                context,
                resolvedRequiredTier,
                scope.currentTier,
              );
            }

            return Scaffold(
              body: Center(
                child: DefaultLockedWidget(
                  requiredTier: resolvedRequiredTier,
                  currentTier: scope.currentTier,
                  onUpgradePressed: () => scope.requestUpgrade(requiredTier),
                ),
              ),
            );
          },
        );

  /// The minimum tier id required to see the page content.
  final String requiredTier;

  /// An optional widget builder displayed when the user is blocked.
  ///
  /// Receives the [BuildContext], the required [Tier], and the user's
  /// current [Tier]. If `null`, a default [Scaffold] with a centered
  /// [DefaultLockedWidget] is shown.
  final Widget Function(
    BuildContext context,
    Tier requiredTier,
    Tier currentTier,
  )? blockedBuilder;

  /// An optional callback invoked when the user is blocked from viewing
  /// the page.
  ///
  /// Receives the required [Tier] and the user's current [Tier].
  final void Function(Tier requiredTier, Tier currentTier)? onBlocked;

  /// Whether to grant access to trialing users.
  ///
  /// Defaults to `true`.
  final bool allowDuringTrial;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Builds a redirect path with optional query parameters.
String _buildRedirectPath(
  String basePath,
  Map<String, String>? queryParams,
) {
  if (queryParams == null || queryParams.isEmpty) {
    return basePath;
  }

  final uri = Uri.parse(basePath).replace(queryParameters: queryParams);
  return uri.toString();
}
