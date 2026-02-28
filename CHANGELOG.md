## 0.0.1 — 2026-02-28

- Initial release
- SubscriptionGuard widget with 4 guard behaviors (hide, disable, replace, blur)
- Feature-based gating with SubscriptionGuard.feature()
- Specific tier gating with SubscriptionGuard.allowedTiers()
- Navigation route guards (pushGuarded, SubscriptionPageRoute, GoRouter compatible redirect)
- Trial support with TrialBanner and countdown
- Debug overlay for tier switching during development
- Programmatic access checks via SubscriptionGuardScope
- Analytics callbacks (onFeatureBlocked, onUpgradeRequested)
- Zero external dependencies — pure Flutter
