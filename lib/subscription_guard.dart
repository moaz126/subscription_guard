/// A declarative, provider-agnostic subscription tier gating package for Flutter.
///
/// Gate features, widgets, and routes based on subscription tiers
/// with zero purchase SDK dependency.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:subscription_guard/subscription_guard.dart';
///
///  1. Define your tiers
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
///  2. Wrap your app
/// SubscriptionGuardProvider(
///   config: config,
///   currentTier: 'free',
///   onUpgradeRequested: (tier) => showPaywall(tier),
///   child: MyApp(),
/// );
///
/// 3. Guard any widget
/// SubscriptionGuard(
///   requiredTier: 'pro',
///   child: PremiumFeatureWidget(),
/// );
/// ```
library;

// --- Models ---
// Core data classes and enums for defining tiers, behaviors, and trial state.

export 'src/models/tier.dart' show Tier;
export 'src/models/tier_config.dart' show SubscriptionConfig;
export 'src/models/guard_behavior.dart' show GuardBehavior;
export 'src/models/trial_info.dart' show TrialInfo;

// --- Providers ---
// State management widgets. Wrap your app with SubscriptionGuardProvider
// and read state via SubscriptionGuardScope.of(context).

export 'src/providers/subscription_guard_provider.dart'
    show SubscriptionGuardProvider;
export 'src/providers/subscription_guard_scope.dart'
    show SubscriptionGuardScope;

// --- Widgets ---
// UI components for gating features and displaying trial status.

export 'src/widgets/subscription_guard.dart' show SubscriptionGuard;
export 'src/widgets/default_locked_widget.dart' show DefaultLockedWidget;
export 'src/widgets/trial_banner.dart' show TrialBanner;
export 'src/widgets/debug_overlay.dart'
    show SubscriptionGuardDebugOverlay, DebugOverlayPosition;

// --- Navigation ---
// Route protection utilities. Compatible with GoRouter (without depending
// on it), Navigator 2.0, and manual navigation.

export 'src/navigation/subscription_route_guard.dart'
    show
        subscriptionRedirect,
        subscriptionFeatureRedirect,
        SubscriptionRouteGuard,
        RouteAccessResult,
        SubscriptionPageRoute;
