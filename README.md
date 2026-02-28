# subscription_guard

A declarative, provider-agnostic subscription tier gating package for Flutter.

[![pub package](https://img.shields.io/pub/v/subscription_guard.svg)](https://pub.dev/packages/subscription_guard)
[![pub points](https://img.shields.io/pub/points/subscription_guard)](https://pub.dev/packages/subscription_guard/score)
[![likes](https://img.shields.io/pub/likes/subscription_guard)](https://pub.dev/packages/subscription_guard)
[![popularity](https://img.shields.io/pub/popularity/subscription_guard)](https://pub.dev/packages/subscription_guard/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/YOUR_GITHUB_USERNAME/subscription_guard/blob/main/LICENSE)
[![flutter](https://img.shields.io/badge/flutter-≥3.10.0-blue.svg)](https://flutter.dev)

**Stop writing `if/else` for every premium feature. Gate any widget, route, or feature with one line of code.**

---

## The Problem

```dart
// This is scattered across your entire codebase 😩
if (user.subscription == 'pro' || user.subscription == 'premium') {
  return AdvancedStatsWidget();
} else {
  return UpgradePrompt();
}
// And again here... and in your routes... and in your navigation...
// 35+ features? That's 35+ if/else blocks. Good luck maintaining that.
```

## The Solution

```dart
// One line. Done. ✅
SubscriptionGuard(
  requiredTier: 'pro',
  child: AdvancedStatsWidget(),
)
```

---

## ✨ Features

- 🛡️ **Declarative Gating** — `SubscriptionGuard` widget for tier, feature, or specific-tier gating
- 🎨 **4 Guard Behaviors** — Hide, Disable, Blur, or Replace locked content
- 🧭 **Route Protection** — Guard entire screens with navigation helpers
- ⏱️ **Trial Support** — Built-in trial countdown with `TrialBanner`
- 📊 **Analytics Callbacks** — Track which features users hit paywalls on
- 🔌 **Provider Agnostic** — Works with RevenueCat, Adapty, or any purchase SDK
- 🐛 **Debug Overlay** — Draggable tier switcher for testing during development
- 📦 **Zero Dependencies** — Pure Flutter, no external packages
- 🎯 **Feature Registry** — Map features to tiers centrally, reference by ID
- 💡 **Programmatic Access** — Check tier access anywhere in code

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  subscription_guard: ^0.0.1
```

Then run:

```bash
flutter pub get
```

---

## 🚀 Quick Start

### Step 1: Define your tiers

```dart
final config = SubscriptionConfig(
  tiers: [
    Tier(id: 'free', level: 0, label: 'Free'),
    Tier(id: 'pro', level: 1, label: 'Pro'),
    Tier(id: 'premium', level: 2, label: 'Premium'),
  ],
  features: {
    'advanced_stats': 'pro',
    'export_pdf': 'pro',
    'team_management': 'premium',
  },
);
```

### Step 2: Wrap your app

```dart
SubscriptionGuardProvider(
  config: config,
  currentTier: 'free', // Update this when user purchases
  onUpgradeRequested: (requiredTier) {
    // Show your paywall (RevenueCat, Adapty, etc.)
    showPaywall(requiredTier);
  },
  child: MyApp(),
)
```

### Step 3: Guard any widget

```dart
SubscriptionGuard(
  requiredTier: 'pro',
  child: AdvancedStatsWidget(),
)
```

**That's it!** The widget automatically shows or hides based on the user's tier. When the tier changes, all guards update instantly.

---

## 📚 Usage

### Guard Behaviors

```dart
// Hide — completely removes from widget tree
SubscriptionGuard(requiredTier: 'pro', behavior: GuardBehavior.hide, child: ProWidget())

// Disable — visible but greyed out and non-interactive
SubscriptionGuard(requiredTier: 'pro', behavior: GuardBehavior.disable, child: ProWidget())

// Replace — shows locked UI (default behavior)
SubscriptionGuard(requiredTier: 'pro', behavior: GuardBehavior.replace, child: ProWidget())

// Blur — shows blurred preview with adaptive lock overlay
SubscriptionGuard(requiredTier: 'pro', behavior: GuardBehavior.blur, child: ProWidget())
```

### Feature-Based Gating

```dart
// Define features in config, reference by ID
SubscriptionGuard.feature(
  featureId: 'export_pdf',
  child: ExportButton(),
)
```

### Specific Tier Gating (Non-Hierarchical)

```dart
// Only 'pro' users — NOT premium, NOT free
SubscriptionGuard.allowedTiers(
  tierIds: ['pro'],
  child: ProExclusiveBadge(),
)
```

### Custom Locked Widget

```dart
SubscriptionGuard(
  requiredTier: 'premium',
  lockedBuilder: (context, requiredTier, currentTier) {
    return MyCustomPaywall(tier: requiredTier);
  },
  child: PremiumFeature(),
)
```

### Navigation Guards

```dart
// Method 1: pushGuarded — blocks navigation if tier insufficient
SubscriptionRouteGuard.pushGuarded(
  context,
  requiredTier: 'pro',
  route: MaterialPageRoute(builder: (_) => AnalyticsScreen()),
  onBlocked: (required, current) => showUpgradeDialog(required),
);

// Method 2: SubscriptionPageRoute — always pushes, shows locked UI if blocked
Navigator.of(context).push(
  SubscriptionPageRoute(
    requiredTier: 'pro',
    builder: (_) => AnalyticsScreen(),
  ),
);

// Method 3: GoRouter compatible redirect (no go_router dependency required)
GoRoute(
  path: '/analytics',
  redirect: subscriptionRedirect(
    requiredTier: 'pro',
    redirectPath: '/upgrade',
  ),
)
```

### Programmatic Access Check

```dart
final scope = SubscriptionGuardScope.of(context);

if (scope.hasAccess('pro')) {
  // Do something for pro users
}

if (scope.hasFeatureAccess('export_pdf')) {
  // Feature is accessible
}

// Or use the route guard utility
final result = SubscriptionRouteGuard.checkAccess(context, requiredTier: 'pro');
if (result.hasAccess) { /* ... */ }
```

### Trial Support

```dart
SubscriptionGuardProvider(
  config: config,
  currentTier: 'pro',
  trialInfo: TrialInfo(
    isTrialing: true,
    endsAt: DateTime.now().add(Duration(days: 7)),
  ),
  child: Column(
    children: [
      TrialBanner(onTap: () => showUpgradeDialog()),
      SubscriptionGuard(
        requiredTier: 'pro',
        allowDuringTrial: true, // default
        child: ProFeature(),
      ),
    ],
  ),
)
```

### Analytics / Tracking

```dart
SubscriptionGuardProvider(
  config: config,
  currentTier: 'free',
  onFeatureBlocked: (featureId, requiredTier, currentTier) {
    analytics.track('feature_gated', {
      'feature': featureId,
      'required_tier': requiredTier.id,
      'current_tier': currentTier.id,
    });
  },
  onUpgradeRequested: (requiredTier) {
    analytics.track('upgrade_requested', {'tier': requiredTier.id});
  },
  child: MyApp(),
)
```

### Debug Overlay

```dart
SubscriptionGuardDebugOverlay(
  enabled: kDebugMode, // Auto-disabled in release builds
  onTierChanged: (tierId) {
    setState(() => _currentTier = tierId);
  },
  child: MyApp(),
)
```

---

## 🔌 Works With Any Purchase SDK

subscription_guard doesn't handle purchases — it only handles **UI gating**. Pair it with your preferred purchase SDK:

**RevenueCat:**

```dart
Purchases.addCustomerInfoUpdateListener((info) {
  final tier = info.entitlements.active.containsKey('premium')
      ? 'premium'
      : info.entitlements.active.containsKey('pro') ? 'pro' : 'free';
  setState(() => _currentTier = tier);
});
```

**Adapty:**

```dart
Adapty.getProfile().then((profile) {
  final tier = profile.accessLevels['premium']?.isActive == true
      ? 'premium' : 'free';
  setState(() => _currentTier = tier);
});
```

**Raw in_app_purchase:**

```dart
InAppPurchase.instance.purchaseStream.listen((purchases) {
  setState(() => _currentTier = deriveTierFromPurchases(purchases));
});
```

Just update `currentTier` on the provider — subscription_guard handles the rest.

---

## 🏗️ Architecture

subscription_guard uses a pure `InheritedWidget` architecture — no BLoC, Riverpod, or Provider dependency. Your purchase SDK feeds the current tier into `SubscriptionGuardProvider`, which propagates it down the widget tree. Every `SubscriptionGuard`, `SubscriptionRouteGuard`, and `TrialBanner` reacts automatically when the tier changes.

```
┌──────────────────────────────────────────────────┐
│              Your Purchase SDK                    │
│         (RevenueCat / Adapty / etc.)              │
│                      │                            │
│                      ▼                            │
│      SubscriptionGuardProvider(currentTier)       │
│                      │                            │
│           ┌──────────┼──────────┐                 │
│           ▼          ▼          ▼                 │
│   SubscriptionGuard  RouteGuard  TrialBanner      │
│           │          │          │                 │
│      ┌────┴────┐   Access    Countdown            │
│      │ Access? │   Check                          │
│      ├─Yes─►Show│                                 │
│      └─No──►Lock│                                 │
└──────────────────────────────────────────────────┘
```

---

## 📖 API Reference

Full API documentation is available at:
[pub.dev/documentation/subscription_guard](https://pub.dev/documentation/subscription_guard/latest/)

### Key Classes

| Class | Description |
|---|---|
| `SubscriptionGuardProvider` | Root widget that provides tier state to the tree |
| `SubscriptionGuard` | Core gating widget — tier, feature, or allowedTiers |
| `SubscriptionConfig` | Configuration for tiers and feature mappings |
| `Tier` | Represents a single subscription tier |
| `GuardBehavior` | Enum: hide, disable, replace, blur |
| `TrialInfo` | Trial period state |
| `TrialBanner` | Trial countdown banner widget |
| `DefaultLockedWidget` | Built-in locked state UI |
| `SubscriptionRouteGuard` | Static navigation guard utilities |
| `SubscriptionPageRoute` | MaterialPageRoute with built-in tier check |
| `RouteAccessResult` | Result of a programmatic access check |
| `SubscriptionGuardDebugOverlay` | Debug tier switcher overlay |
| `SubscriptionGuardScope` | Programmatic access to subscription state |

---

## 🎮 Example

Check out the [example app](example/) for a complete demo of all features.

```bash
cd example
flutter create .  # Generate platform files (first time only)
flutter run
```

The example app includes:
- Tier switching simulation
- All 4 guard behaviors
- Feature-based gating
- Navigation guards
- Trial banner
- Debug overlay
- Custom locked builders
- Analytics callback logging

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please make sure to:
- Update tests as appropriate
- Follow existing code style
- Add documentation for new features
- Run `dart analyze` and `flutter test` before submitting

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

Built with ❤️ by [YOUR_NAME](https://github.com/YOUR_GITHUB_USERNAME)

If this package helps you, please ⭐ the repo and 👍 on [pub.dev](https://pub.dev/packages/subscription_guard)!
