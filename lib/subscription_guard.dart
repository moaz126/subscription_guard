/// A declarative, provider-agnostic subscription tier gating package for Flutter.
///
/// Gate features, widgets, and routes based on subscription tiers
/// with zero purchase SDK dependency.
///
/// ## Overview
///
/// `subscription_guard` lets you define subscription tiers, map features to
/// those tiers, and declaratively gate any widget, route, or action based on
/// the user's current tier — all without coupling to a specific purchase SDK.
///
/// The package follows Flutter's [InheritedWidget] pattern:
///
/// 1. **Configure** your tiers and features with [SubscriptionConfig].
/// 2. **Provide** subscription state with [SubscriptionGuardProvider].
/// 3. **Guard** widgets with [SubscriptionGuard] and routes with
///    [SubscriptionRouteGuard] or [subscriptionRedirect].
/// 4. **Display** trial status with [TrialBanner].
/// 5. **Debug** with [SubscriptionGuardDebugOverlay].
///
/// ## Quick Start
///
/// ```dart
/// import 'package:subscription_guard/subscription_guard.dart';
///
/// // 1. Define your tiers
/// final config = SubscriptionConfig(
///   tiers: [
///     Tier(id: 'free', level: 0, label: 'Free'),
///     Tier(id: 'pro', level: 1, label: 'Pro'),
///     Tier(id: 'premium', level: 2, label: 'Premium'),
///   ],
///   features: {
///     'advanced_stats': 'pro',
///     'export_pdf': 'pro',
///     'team_management': 'premium',
///   },
/// );
///
/// // 2. Wrap your app
/// SubscriptionGuardProvider(
///   config: config,
///   currentTier: 'free',
///   onUpgradeRequested: (tier) => showPaywall(tier),
///   child: MyApp(),
/// );
///
/// // 3. Guard any widget
/// SubscriptionGuard(
///   requiredTier: 'pro',
///   child: PremiumFeatureWidget(),
/// );
/// ```
///
/// ## Key Classes
///
/// | Class | Purpose |
/// |---|---|
/// | [Tier] | Represents a single subscription tier. |
/// | [SubscriptionConfig] | Central config with tiers and feature map. |
/// | [GuardBehavior] | Controls locked behavior (hide, disable, replace, blur). |
/// | [TrialInfo] | Tracks trial/grace period state. |
/// | [SubscriptionGuardProvider] | Top-level state widget (wrap your app). |
/// | [SubscriptionGuardScope] | InheritedWidget for reading state. |
/// | [SubscriptionGuard] | Declarative widget-level gating. |
/// | [DefaultLockedWidget] | Built-in locked UI fallback. |
/// | [TrialBanner] | Trial countdown banner. |
/// | [SubscriptionGuardDebugOverlay] | Dev-only debug panel. |
/// | [SubscriptionRouteGuard] | Programmatic route access checks. |
/// | [subscriptionRedirect] | GoRouter-compatible redirect (tier). |
/// | [subscriptionFeatureRedirect] | GoRouter-compatible redirect (feature). |
/// | [SubscriptionPageRoute] | MaterialPageRoute with built-in gating. |
/// | [RouteAccessResult] | Result of a route access check. |
library;

// --- Models ---
// Core data classes and enums for defining tiers, behaviors, and trial state.
//
// - [Tier]: A single subscription tier with id, level, and label.
// - [SubscriptionConfig]: Central config holding all tiers and feature
//   mappings.
// - [GuardBehavior]: Enum controlling locked behavior.
// - [TrialInfo]: Trial/grace period state with computed properties.

export 'src/models/tier.dart' show Tier;
export 'src/models/tier_config.dart' show SubscriptionConfig;
export 'src/models/guard_behavior.dart' show GuardBehavior;
export 'src/models/trial_info.dart' show TrialInfo;

// --- Providers ---
// State management widgets. Wrap your app with [SubscriptionGuardProvider]
// and read state via [SubscriptionGuardScope.of(context)].
//
// - [SubscriptionGuardProvider]: Top-level StatefulWidget that resolves
//   tier strings and propagates state.
// - [SubscriptionGuardScope]: InheritedWidget accessed by descendant widgets.

export 'src/providers/subscription_guard_provider.dart'
    show SubscriptionGuardProvider;
export 'src/providers/subscription_guard_scope.dart'
    show SubscriptionGuardScope;

// --- Widgets ---
// UI components for gating features and displaying trial status.
//
// - [SubscriptionGuard]: Declarative widget with 3 constructors (tier,
//   feature, allowedTiers).
// - [DefaultLockedWidget]: Built-in locked state UI (normal and compact).
// - [TrialBanner]: Trial countdown banner with urgent/expired states.
// - [SubscriptionGuardDebugOverlay]: Draggable dev-only debug panel.
// - [DebugOverlayPosition]: Initial FAB position for the debug overlay.

export 'src/widgets/subscription_guard.dart' show SubscriptionGuard;
export 'src/widgets/default_locked_widget.dart' show DefaultLockedWidget;
export 'src/widgets/trial_banner.dart' show TrialBanner;
export 'src/widgets/debug_overlay.dart'
    show SubscriptionGuardDebugOverlay, DebugOverlayPosition;

// --- Navigation ---
// Route protection utilities. Compatible with GoRouter (without depending
// on it), Navigator 2.0, and manual navigation.
//
// - [subscriptionRedirect]: GoRouter redirect function (tier-based).
// - [subscriptionFeatureRedirect]: GoRouter redirect function (feature-based).
// - [SubscriptionRouteGuard]: Static methods for programmatic access checks
//   and guarded navigation (checkAccess, pushGuarded, etc.).
// - [SubscriptionPageRoute]: MaterialPageRoute with built-in tier gating.
// - [RouteAccessResult]: Result object from access check methods.

export 'src/navigation/subscription_route_guard.dart'
    show
        subscriptionRedirect,
        subscriptionFeatureRedirect,
        SubscriptionRouteGuard,
        RouteAccessResult,
        SubscriptionPageRoute;
