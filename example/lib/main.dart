/// subscription_guard — Example App
///
/// Run this example:
///   cd example && flutter run
///
/// This single-file example demonstrates every major feature of the
/// subscription_guard package. Use the tier-switcher bar at the top (or the
/// debug overlay FAB in the bottom-right corner) to switch subscription
/// tiers and watch features lock/unlock in real time.
///
/// Features demonstrated:
///  1. Basic tier gating            (SubscriptionGuard)
///  2. Feature-based gating         (SubscriptionGuard.feature)
///  3. Specific-tier gating         (SubscriptionGuard.allowedTiers)
///  4. GuardBehavior.replace        (default)
///  5. GuardBehavior.blur           (blurred preview)
///  6. GuardBehavior.disable        (greyed out)
///  7. GuardBehavior.hide           (removed from tree)
///  8. Custom lockedBuilder         (fully custom locked UI)
///  9. Trial banner with countdown  (TrialBanner)
/// 10. Navigation route guard       (pushGuarded)
/// 11. Protected page route         (SubscriptionPageRoute)
/// 12. Programmatic access check    (checkAccess / SubscriptionGuardScope)
/// 13. Debug overlay                (SubscriptionGuardDebugOverlay)
/// 14. Upgrade request callback     (onUpgradeRequested → paywall)
/// 15. Feature blocked analytics    (onFeatureBlocked → logging)
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:subscription_guard/subscription_guard.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Define subscription tiers and features
// ─────────────────────────────────────────────────────────────────────────────

/// Tier & feature configuration for the entire app.
///
/// In a real app you would define this once and share it across the project.
/// Tiers are ordered by level — higher level = more access.
/// Features map a feature id to the minimum tier id required.
final subscriptionConfig = SubscriptionConfig(
  tiers: const [
    Tier(id: 'free', level: 0, label: 'Free'),
    Tier(id: 'pro', level: 1, label: 'Pro'),
    Tier(id: 'premium', level: 2, label: 'Premium'),
  ],
  features: const {
    // Free features
    'basic_stats': 'free',
    'dark_mode': 'free',
    // Pro features
    'advanced_stats': 'pro',
    'export_pdf': 'pro',
    'custom_themes': 'pro',
    // Premium features
    'team_management': 'premium',
    'api_access': 'premium',
    'priority_support': 'premium',
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Root widget — manages subscription state
// ─────────────────────────────────────────────────────────────────────────────

/// The root widget owns [_currentTier] and [_trialInfo] because in a real app
/// these values come from your purchase SDK (RevenueCat, Adapty, etc.) and
/// you push updates down to [SubscriptionGuardProvider] whenever the user's
/// entitlements change.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String _currentTier = 'free';
  TrialInfo _trialInfo = const TrialInfo.none();

  // ── public helpers so child widgets can trigger tier/trial changes ──

  void changeTier(String tierId) => setState(() => _currentTier = tierId);

  void toggleTrial(bool enabled) {
    setState(() {
      _trialInfo = enabled
          ? TrialInfo(
              isTrialing: true,
              endsAt: DateTime.now().add(const Duration(days: 7)),
            )
          : const TrialInfo.none();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Step 3: Wrap the app with SubscriptionGuardProvider
    return SubscriptionGuardProvider(
      config: subscriptionConfig,
      currentTier: _currentTier,
      trialInfo: _trialInfo,
      defaultBehavior: GuardBehavior.replace,

      // Step 4: Handle upgrade requests — show your paywall here
      onUpgradeRequested: (requiredTier) {
        // In a real app: RevenueCat.showPaywall(), Adapty.showPaywall(), etc.
        _showUpgradeDialog(context, requiredTier);
      },

      // Step 5: Track blocked features — send to your analytics
      onFeatureBlocked: (featureId, requiredTier, currentTier) {
        debugPrint(
          '📊 Analytics: Feature blocked — '
          'feature: $featureId, '
          'required: ${requiredTier.id}, '
          'current: ${currentTier.id}',
        );
      },

      // Step 6: Wrap with the debug overlay for development testing.
      // The overlay must be inside MaterialApp so it has a Directionality
      // ancestor (required by its internal Stack widget). We use the
      // MaterialApp.builder to inject the overlay above every route.
      child: MaterialApp(
        title: 'Subscription Guard Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        builder: (context, child) {
          return SubscriptionGuardDebugOverlay(
            enabled: kDebugMode, // Automatically disabled in release builds
            initialPosition: DebugOverlayPosition.bottomRight,
            onTierChanged: changeTier,
            onTrialToggled: toggleTrial,
            child: child!,
          );
        },
        home: const HomeScreen(),
        routes: {
          '/upgrade': (_) => const UpgradeScreen(),
        },
      ),
    );
  }

  // ── Upgrade dialog ──

  void _showUpgradeDialog(BuildContext rootContext, Tier requiredTier) {
    // We need a navigator context — use the MaterialApp's navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = navigator?.overlay?.context;
      if (navContext == null) return;
      showDialog<void>(
        context: navContext,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.workspace_premium, size: 48),
          title: Text('Upgrade to ${requiredTier.label}'),
          content: Text(
            'This feature requires the ${requiredTier.label} plan.\n\n'
            'In a real app this would open your RevenueCat or Adapty paywall.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () {
                // Simulate purchase — upgrade immediately
                changeTier(requiredTier.id);
                Navigator.pop(ctx);
              },
              child: Text('Upgrade to ${requiredTier.label}'),
            ),
          ],
        ),
      );
    });
  }

  NavigatorState? get navigator {
    try {
      return Navigator.of(context);
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — main demo screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SubscriptionGuardScope.of(context);
    final appState = context.findAncestorStateOfType<MyAppState>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Guard Demo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: const Icon(Icons.person, size: 18),
              label: Text(scope.currentTier.label),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ────────────────────────────────────────────────────────────────
            // Tier Switcher
            // ────────────────────────────────────────────────────────────────
            // In a real app, tier changes come from your purchase SDK.
            // Here we simulate it with a segmented button.
            _buildSectionHeader(
              context,
              'Tier Switcher',
              'Simulate tier changes (purchase SDK in production)',
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'free', label: Text('Free')),
                ButtonSegment(value: 'pro', label: Text('Pro')),
                ButtonSegment(value: 'premium', label: Text('Premium')),
              ],
              selected: {scope.currentTier.id},
              onSelectionChanged: (selected) =>
                  appState.changeTier(selected.first),
            ),

            const SizedBox(height: 8),

            // Trial Toggle
            Row(
              children: [
                const Text('Trial Mode:'),
                Switch(
                  value: scope.isTrialing,
                  onChanged: appState.toggleTrial,
                ),
                if (scope.trialInfo.isActive &&
                    scope.trialInfo.daysRemaining != null)
                  Text(
                    '${scope.trialInfo.daysRemaining} days left',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),

            const Divider(height: 32),

            // ────────────────────────────────────────────────────────────────
            // Demo 1: Trial Banner
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 1 — Trial Banner',
              'Shows trial countdown. Toggle trial mode above to see it.',
            ),
            TrialBanner(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigate to upgrade page')),
                );
              },
            ),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 2: GuardBehavior.replace (default)
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 2 — GuardBehavior.replace',
              'Replaces the widget with a locked UI when tier is insufficient.',
            ),
            SubscriptionGuard(
              requiredTier: 'pro',
              // behavior: GuardBehavior.replace is the default
              child: _buildFeatureCard(
                context,
                icon: Icons.bar_chart,
                title: 'Advanced Analytics',
                subtitle: 'Detailed performance charts and insights',
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 3: GuardBehavior.blur
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 3 — GuardBehavior.blur',
              'Shows a blurred preview with a lock overlay — great for teasing.',
            ),
            SubscriptionGuard(
              requiredTier: 'premium',
              behavior: GuardBehavior.blur,
              child: _buildFeatureCard(
                context,
                icon: Icons.groups,
                title: 'Team Management',
                subtitle: 'Invite team members and manage roles',
                color: Colors.purple,
              ),
            ),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 4: GuardBehavior.disable
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 4 — GuardBehavior.disable',
              'Shows the widget greyed-out and non-interactive.',
            ),
            SubscriptionGuard(
              requiredTier: 'pro',
              behavior: GuardBehavior.disable,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF exported!')),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export as PDF'),
              ),
            ),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 5: GuardBehavior.hide
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 5 — GuardBehavior.hide',
              'Completely removes the widget. Free users will never see it.',
            ),
            SubscriptionGuard(
              requiredTier: 'premium',
              behavior: GuardBehavior.hide,
              child: _buildFeatureCard(
                context,
                icon: Icons.api,
                title: 'API Access',
                subtitle: 'REST API for third-party integrations',
                color: Colors.teal,
              ),
            ),
            // Visible hint so the demo effect is obvious
            Builder(builder: (ctx) {
              final s = SubscriptionGuardScope.of(ctx);
              if (!s.hasAccess('premium')) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '(API Access card is hidden — switch to Premium to reveal)',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(ctx).colorScheme.outline,
                        ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 6: Feature-based Gating
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 6 — Feature-based Gating',
              'Specify a feature ID instead of a tier. The required tier '
                  'is resolved from the config automatically.',
            ),
            SubscriptionGuard.feature(
              featureId: 'custom_themes',
              child: _buildFeatureCard(
                context,
                icon: Icons.palette,
                title: 'Custom Themes',
                subtitle: 'Personalize your app appearance',
                color: Colors.orange,
              ),
            ),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 7: Specific Tier Gating (allowedTiers)
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 7 — Allowed Tiers (Exact Match)',
              'Only Pro users see this — NOT hierarchy-based. '
                  'Premium users cannot access it either!',
            ),
            SubscriptionGuard.allowedTiers(
              tierIds: const ['pro'],
              child: _buildFeatureCard(
                context,
                icon: Icons.star,
                title: 'Pro Exclusive Badge',
                subtitle: 'This feature is ONLY for Pro users, not Premium!',
                color: Colors.amber,
              ),
            ),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 8: Custom lockedBuilder
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 8 — Custom Locked Builder',
              'Provide your own widget when a feature is locked.',
            ),
            SubscriptionGuard(
              requiredTier: 'premium',
              lockedBuilder: (ctx, requiredTier, currentTier) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(ctx).colorScheme.tertiary,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(ctx)
                        .colorScheme
                        .tertiaryContainer
                        .withAlpha(80),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: Theme.of(ctx).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Priority Support',
                              style: Theme.of(ctx).textTheme.titleSmall,
                            ),
                            Text(
                              'Upgrade to ${requiredTier.label} '
                              'for 24/7 priority support',
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          SubscriptionGuardScope.of(ctx)
                              .requestUpgrade(requiredTier.id);
                        },
                        child: const Text('Upgrade'),
                      ),
                    ],
                  ),
                );
              },
              child: _buildFeatureCard(
                context,
                icon: Icons.support_agent,
                title: 'Priority Support',
                subtitle: '24/7 dedicated support team',
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 9: Navigation Guards
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 9 — Navigation Guards',
              'Protect entire screens behind a tier.',
            ),

            // Method A: pushGuarded — blocks navigation if tier insufficient
            FilledButton.icon(
              onPressed: () {
                SubscriptionRouteGuard.pushGuarded(
                  context,
                  requiredTier: 'pro',
                  route: MaterialPageRoute<void>(
                    builder: (_) => const AnalyticsScreen(),
                  ),
                  onBlocked: (requiredTier, currentTier) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Upgrade to ${requiredTier.label} to access Analytics',
                        ),
                        action: SnackBarAction(
                          label: 'Upgrade',
                          onPressed: () {
                            SubscriptionGuardScope.of(context)
                                .requestUpgrade(requiredTier.id);
                          },
                        ),
                      ),
                    );
                  },
                  requestUpgradeOnBlock: false,
                );
              },
              icon: const Icon(Icons.analytics),
              label: const Text('Open Analytics (pushGuarded — Pro)'),
            ),

            const SizedBox(height: 8),

            // Method B: SubscriptionPageRoute — always pushes, shows
            // blocked UI if tier insufficient
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  SubscriptionPageRoute<void>(
                    requiredTier: 'premium',
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Team Dashboard')),
                      body: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.dashboard, size: 64),
                            SizedBox(height: 16),
                            Text('Team Dashboard — Premium Only'),
                          ],
                        ),
                      ),
                    ),
                    onBlocked: (required, current) {
                      debugPrint(
                        'Navigation blocked: needs ${required.label}',
                      );
                    },
                  ),
                );
              },
              icon: const Icon(Icons.dashboard),
              label: const Text('Team Dashboard (PageRoute — Premium)'),
            ),

            const SizedBox(height: 24),

            // ────────────────────────────────────────────────────────────────
            // Demo 10: Programmatic Access Check
            // ────────────────────────────────────────────────────────────────
            _buildSectionHeader(
              context,
              'Demo 10 — Programmatic Access Check',
              'Check access without a widget — useful for conditional logic.',
            ),

            OutlinedButton.icon(
              onPressed: () {
                final result = SubscriptionRouteGuard.checkAccess(
                  context,
                  requiredTier: 'pro',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.hasAccess
                          ? 'You have Pro access!'
                          : 'Pro required. You are on '
                              '${result.currentTier.label}.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.verified_user),
              label: const Text('Check Pro Access'),
            ),

            const SizedBox(height: 12),

            // Show accessible features using SubscriptionGuardScope
            Builder(builder: (ctx) {
              final s = SubscriptionGuardScope.of(ctx);
              final features = s.accessibleFeatures;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accessible features (${features.length}):',
                        style: Theme.of(ctx).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: features
                            .map((f) => Chip(
                                  label: Text(f),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Section header with title and description.
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  /// Reusable feature card for demo purposes.
  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title tapped!')),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsScreen — protected route destination
// ─────────────────────────────────────────────────────────────────────────────

/// A demo screen representing a Pro-only feature screen.
/// Users navigate here via the navigation guard demos.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SubscriptionGuardScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics (Pro)')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics, size: 64, color: Colors.indigo),
            const SizedBox(height: 16),
            Text(
              'Welcome to Advanced Analytics!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This screen is protected by SubscriptionRouteGuard.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Current tier: ${scope.currentTier.label}'),
            if (scope.isTrialing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '(Accessing via trial)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UpgradeScreen — simple upgrade page
// ─────────────────────────────────────────────────────────────────────────────

/// A simple upgrade screen shown when user is redirected from a protected
/// route. In a real app this would be your paywall.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_open, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Upgrade Your Plan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('This is where your paywall would go.'),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
