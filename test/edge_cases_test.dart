// Edge case tests for the subscription_guard package — covering single tier
// configs, empty feature maps, invalid tier handling, rapid tier switching,
// nested/sibling guards, trial boundary conditions, allowedTiers deep dive,
// many-tier stress tests, non-sequential levels, and negative levels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_guard/subscription_guard.dart';

// ---------------------------------------------------------------------------
// Test helpers (independent copy — no shared state with widget tests)
// ---------------------------------------------------------------------------

/// Wraps a widget with MaterialApp + SubscriptionGuardProvider.
Widget buildTestApp({
  required String currentTier,
  required Widget child,
  SubscriptionConfig? config,
  TrialInfo? trialInfo,
  GuardBehavior defaultBehavior = GuardBehavior.replace,
}) {
  return MaterialApp(
    home: SubscriptionGuardProvider(
      config: config ?? defaultTestConfig,
      currentTier: currentTier,
      trialInfo: trialInfo ?? const TrialInfo.none(),
      defaultBehavior: defaultBehavior,
      child: Scaffold(body: child),
    ),
  );
}

/// Default 4-tier config.
final defaultTestConfig = SubscriptionConfig(
  tiers: const [
    Tier(id: 'free', level: 0, label: 'Free'),
    Tier(id: 'basic', level: 1, label: 'Basic'),
    Tier(id: 'pro', level: 2, label: 'Pro'),
    Tier(id: 'premium', level: 3, label: 'Premium'),
  ],
  features: const {
    'basic_stats': 'free',
    'advanced_stats': 'pro',
    'export_pdf': 'pro',
    'team_management': 'premium',
  },
);

/// StatefulWidget that lets tests change tier via GlobalKey.
class _TierChanger extends StatefulWidget {
  const _TierChanger({
    super.key,
    required this.config,
    required this.initialTier,
    required this.child,
    this.trialInfo = const TrialInfo.none(),
  });
  final SubscriptionConfig config;
  final String initialTier;
  final Widget child;
  final TrialInfo trialInfo;

  @override
  State<_TierChanger> createState() => _TierChangerState();
}

class _TierChangerState extends State<_TierChanger> {
  late String _currentTier;
  late TrialInfo _trialInfo;

  @override
  void initState() {
    super.initState();
    _currentTier = widget.initialTier;
    _trialInfo = widget.trialInfo;
  }

  void changeTier(String tier) => setState(() => _currentTier = tier);
  void changeTrialInfo(TrialInfo info) => setState(() => _trialInfo = info);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SubscriptionGuardProvider(
        config: widget.config,
        currentTier: _currentTier,
        trialInfo: _trialInfo,
        child: Scaffold(body: widget.child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  // =========================================================================
  // Group 1: Single tier config
  // =========================================================================
  group('Edge Cases — single tier config', () {
    final singleTierConfig = SubscriptionConfig(
      tiers: const [Tier(id: 'default', level: 0, label: 'Default')],
      features: const {'only_feature': 'default'},
    );

    testWidgets('works with config that has only one tier', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: singleTierConfig,
        currentTier: 'default',
        child: const SubscriptionGuard(
          requiredTier: 'default',
          child: Text('Visible'),
        ),
      ));

      expect(find.text('Visible'), findsOneWidget);
    });

    testWidgets('single tier config — feature gating works', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: singleTierConfig,
        currentTier: 'default',
        child: const SubscriptionGuard.feature(
          featureId: 'only_feature',
          child: Text('Feature OK'),
        ),
      ));

      expect(find.text('Feature OK'), findsOneWidget);
    });

    testWidgets('single tier config — lowestTier equals highestTier',
        (tester) async {
      late SubscriptionGuardScope scope;

      await tester.pumpWidget(buildTestApp(
        config: singleTierConfig,
        currentTier: 'default',
        child: Builder(builder: (context) {
          scope = SubscriptionGuardScope.of(context);
          return const SizedBox.shrink();
        }),
      ));

      expect(scope.config.lowestTier, scope.config.highestTier);
    });

    testWidgets('single tier config — canAccess returns true for self',
        (tester) async {
      expect(singleTierConfig.canAccess('default', 'default'), isTrue);
    });

    testWidgets(
        'single tier config — getAccessibleFeatures returns all features',
        (tester) async {
      expect(
        singleTierConfig.getAccessibleFeatures('default'),
        equals(['only_feature']),
      );
    });
  });

  // =========================================================================
  // Group 2: Two tier free/paid config
  // =========================================================================
  group('Edge Cases — two tier free/paid config', () {
    final simpleTierConfig = SubscriptionConfig(
      tiers: const [
        Tier(id: 'free', level: 0, label: 'Free'),
        Tier(id: 'paid', level: 1, label: 'Paid'),
      ],
      features: const {
        'basic': 'free',
        'premium_feature': 'paid',
        'another_premium': 'paid',
      },
    );

    testWidgets('free user sees free features', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: simpleTierConfig,
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: 'basic',
          child: Text('Basic Feature'),
        ),
      ));

      expect(find.text('Basic Feature'), findsOneWidget);
    });

    testWidgets('free user blocked from paid features', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: simpleTierConfig,
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: 'premium_feature',
          behavior: GuardBehavior.hide,
          child: Text('Premium'),
        ),
      ));

      expect(find.text('Premium'), findsNothing);
    });

    testWidgets('paid user sees all features', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: simpleTierConfig,
        currentTier: 'paid',
        child: const Column(
          children: [
            SubscriptionGuard.feature(
              featureId: 'basic',
              child: Text('Basic'),
            ),
            SubscriptionGuard.feature(
              featureId: 'premium_feature',
              child: Text('Premium'),
            ),
          ],
        ),
      ));

      expect(find.text('Basic'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('paid user accessible features includes everything',
        (tester) async {
      final features = simpleTierConfig.getAccessibleFeatures('paid');
      expect(
        features,
        unorderedEquals(['basic', 'premium_feature', 'another_premium']),
      );
    });
  });

  // =========================================================================
  // Group 3: Config with no features map
  // =========================================================================
  group('Edge Cases — config with no features map', () {
    final noFeaturesConfig = SubscriptionConfig(
      tiers: const [
        Tier(id: 'free', level: 0, label: 'Free'),
        Tier(id: 'pro', level: 1, label: 'Pro'),
      ],
    );

    testWidgets('tier-based gating works without features', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: noFeaturesConfig,
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.hide,
          child: Text('Pro Content'),
        ),
      ));

      expect(find.text('Pro Content'), findsNothing);
    });

    testWidgets('tier-based gating grants access without features',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: noFeaturesConfig,
        currentTier: 'pro',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          child: Text('Pro Content'),
        ),
      ));

      expect(find.text('Pro Content'), findsOneWidget);
    });

    testWidgets('SubscriptionGuard.feature throws when no features configured',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: noFeaturesConfig,
        currentTier: 'pro',
        child: const SubscriptionGuard.feature(
          featureId: 'anything',
          child: Text('Never'),
        ),
      ));

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect((error as FlutterError).toString(), contains('anything'));
    });

    testWidgets('getAccessibleFeatures returns empty list', (tester) async {
      expect(noFeaturesConfig.getAccessibleFeatures('pro'), isEmpty);
    });

    testWidgets('hasFeature returns false for any feature', (tester) async {
      expect(noFeaturesConfig.hasFeature('anything'), isFalse);
      expect(noFeaturesConfig.hasFeature(''), isFalse);
    });
  });

  // =========================================================================
  // Group 4: Invalid tier handling
  // =========================================================================
  group('Edge Cases — invalid tier handling', () {
    testWidgets('provider throws when initialized with non-existent tier id',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'nonexistent',
        child: const SizedBox.shrink(),
      ));

      final error = tester.takeException();
      expect(error, isA<ArgumentError>());
      expect(
        (error as ArgumentError).message.toString(),
        contains('nonexistent'),
      );
    });

    testWidgets(
        'SubscriptionGuard throws when requiredTier does not exist in config',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'nonexistent_tier',
          child: Text('Never'),
        ),
      ));

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect(
        (error as StateError).message,
        contains('nonexistent_tier'),
      );
    });

    testWidgets(
        'SubscriptionGuard.allowedTiers with non-existent tier id still works for valid tiers',
        (tester) async {
      // 'nonexistent' is in the list but doesn't exist in config.
      // 'free' is also in the list and DOES exist. currentTier is 'free'.
      // The guard checks `tierIds.contains(currentTier.id)` — pure string
      // match, so non-existent IDs are harmless for access check.
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['free', 'nonexistent'],
          child: Text('Allowed'),
        ),
      ));

      expect(find.text('Allowed'), findsOneWidget);
    });

    testWidgets(
        'SubscriptionGuard.allowedTiers blocks when only non-existent tiers listed',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['nonexistent'],
          behavior: GuardBehavior.hide,
          child: Text('Blocked'),
        ),
      ));

      expect(find.text('Blocked'), findsNothing);
    });

    testWidgets('SubscriptionGuard.feature with empty string feature id',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: '',
          child: Text('Never'),
        ),
      ));

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
    });
  });

  // =========================================================================
  // Group 5: Tier change mid-session
  // =========================================================================
  group('Edge Cases — tier change mid-session', () {
    testWidgets(
        'upgrade from free → basic → pro → premium progressively unlocks guards',
        (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          child: const Column(
            children: [
              SubscriptionGuard(
                  requiredTier: 'free',
                  behavior: GuardBehavior.hide,
                  child: Text('FREE')),
              SubscriptionGuard(
                  requiredTier: 'basic',
                  behavior: GuardBehavior.hide,
                  child: Text('BASIC')),
              SubscriptionGuard(
                  requiredTier: 'pro',
                  behavior: GuardBehavior.hide,
                  child: Text('PRO')),
              SubscriptionGuard(
                  requiredTier: 'premium',
                  behavior: GuardBehavior.hide,
                  child: Text('PREMIUM')),
            ],
          ),
        ),
      );

      // Free — only free visible
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('BASIC'), findsNothing);
      expect(find.text('PRO'), findsNothing);
      expect(find.text('PREMIUM'), findsNothing);

      // Upgrade to basic
      key.currentState!.changeTier('basic');
      await tester.pump();
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('BASIC'), findsOneWidget);
      expect(find.text('PRO'), findsNothing);
      expect(find.text('PREMIUM'), findsNothing);

      // Upgrade to pro
      key.currentState!.changeTier('pro');
      await tester.pump();
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('BASIC'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('PREMIUM'), findsNothing);

      // Upgrade to premium
      key.currentState!.changeTier('premium');
      await tester.pump();
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('BASIC'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);
    });

    testWidgets('downgrade from premium → free locks everything except free',
        (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'premium',
          child: const Column(
            children: [
              SubscriptionGuard(
                  requiredTier: 'free',
                  behavior: GuardBehavior.hide,
                  child: Text('FREE')),
              SubscriptionGuard(
                  requiredTier: 'basic',
                  behavior: GuardBehavior.hide,
                  child: Text('BASIC')),
              SubscriptionGuard(
                  requiredTier: 'pro',
                  behavior: GuardBehavior.hide,
                  child: Text('PRO')),
              SubscriptionGuard(
                  requiredTier: 'premium',
                  behavior: GuardBehavior.hide,
                  child: Text('PREMIUM')),
            ],
          ),
        ),
      );

      // Premium — all visible
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('BASIC'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);

      // Downgrade to free
      key.currentState!.changeTier('free');
      await tester.pump();
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('BASIC'), findsNothing);
      expect(find.text('PRO'), findsNothing);
      expect(find.text('PREMIUM'), findsNothing);
    });

    testWidgets('rapid tier switching does not cause errors', (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          child: const SubscriptionGuard(
            requiredTier: 'pro',
            behavior: GuardBehavior.hide,
            child: Text('Content'),
          ),
        ),
      );

      // Rapid switching
      for (final tier in [
        'pro',
        'free',
        'premium',
        'basic',
        'free',
        'pro',
        'basic'
      ]) {
        key.currentState!.changeTier(tier);
        await tester.pump();
      }

      // Final state: basic — 'pro' required → blocked
      expect(find.text('Content'), findsNothing);

      // No exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('tier change updates multiple guards in different subtrees',
        (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          child: const Row(
            children: [
              Expanded(
                child: SubscriptionGuard(
                  requiredTier: 'basic',
                  behavior: GuardBehavior.hide,
                  child: Text('BRANCH A'),
                ),
              ),
              Expanded(
                child: SubscriptionGuard(
                  requiredTier: 'pro',
                  behavior: GuardBehavior.hide,
                  child: Text('BRANCH B'),
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('BRANCH A'), findsNothing);
      expect(find.text('BRANCH B'), findsNothing);

      key.currentState!.changeTier('pro');
      await tester.pump();

      expect(find.text('BRANCH A'), findsOneWidget);
      expect(find.text('BRANCH B'), findsOneWidget);
    });

    testWidgets('tier change updates SubscriptionGuard.feature() widgets',
        (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          child: const SubscriptionGuard.feature(
            featureId: 'advanced_stats', // requires 'pro'
            behavior: GuardBehavior.hide,
            child: Text('Stats'),
          ),
        ),
      );

      expect(find.text('Stats'), findsNothing);

      key.currentState!.changeTier('pro');
      await tester.pump();
      expect(find.text('Stats'), findsOneWidget);

      key.currentState!.changeTier('free');
      await tester.pump();
      expect(find.text('Stats'), findsNothing);
    });

    testWidgets('tier change updates SubscriptionGuard.allowedTiers() widgets',
        (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          child: const SubscriptionGuard.allowedTiers(
            tierIds: ['pro', 'premium'],
            behavior: GuardBehavior.hide,
            child: Text('Allowed'),
          ),
        ),
      );

      expect(find.text('Allowed'), findsNothing);

      key.currentState!.changeTier('basic');
      await tester.pump();
      expect(find.text('Allowed'), findsNothing);

      key.currentState!.changeTier('pro');
      await tester.pump();
      expect(find.text('Allowed'), findsOneWidget);

      key.currentState!.changeTier('premium');
      await tester.pump();
      expect(find.text('Allowed'), findsOneWidget);

      key.currentState!.changeTier('basic');
      await tester.pump();
      expect(find.text('Allowed'), findsNothing);
    });
  });

  // =========================================================================
  // Group 6: Trial scenarios
  // =========================================================================
  group('Edge Cases — trial expired scenarios', () {
    testWidgets('trial expires mid-session locks features', (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          trialInfo: TrialInfo(
            isTrialing: true,
            endsAt: DateTime.now().add(const Duration(days: 5)),
          ),
          child: const SubscriptionGuard(
            requiredTier: 'pro',
            allowDuringTrial: true,
            behavior: GuardBehavior.hide,
            child: Text('Trial Content'),
          ),
        ),
      );

      // Active trial → visible
      expect(find.text('Trial Content'), findsOneWidget);

      // Expire trial
      key.currentState!.changeTrialInfo(
        TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      await tester.pump();

      // Expired → blocked (free user, pro required, trial expired)
      expect(find.text('Trial Content'), findsNothing);
    });

    testWidgets('trial activates mid-session unlocks features', (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          child: const SubscriptionGuard(
            requiredTier: 'pro',
            allowDuringTrial: true,
            behavior: GuardBehavior.hide,
            child: Text('Trial Content'),
          ),
        ),
      );

      // No trial → blocked
      expect(find.text('Trial Content'), findsNothing);

      // Activate trial
      key.currentState!.changeTrialInfo(
        TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
      );
      await tester.pump();

      // Trial active → visible
      expect(find.text('Trial Content'), findsOneWidget);
    });

    testWidgets('trial with null endsAt never expires', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: const TrialInfo(isTrialing: true),
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          allowDuringTrial: true,
          child: Text('Infinite Trial'),
        ),
      ));

      expect(find.text('Infinite Trial'), findsOneWidget);
    });

    testWidgets('trial with endsAt exactly now is considered expired',
        (tester) async {
      // DateTime.now() in the past by the time isExpired checks
      final trial = TrialInfo(
        isTrialing: true,
        endsAt: DateTime.now().subtract(const Duration(milliseconds: 1)),
      );
      expect(trial.isExpired, isTrue);
      expect(trial.isActive, isFalse);
    });

    testWidgets('trial with endsAt 1 second in future is still active',
        (tester) async {
      final trial = TrialInfo(
        isTrialing: true,
        endsAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(trial.isExpired, isFalse);
      expect(trial.isActive, isTrue);
    });

    testWidgets('TrialBanner updates when trial info changes', (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          trialInfo: TrialInfo(
            isTrialing: true,
            endsAt: DateTime.now().add(const Duration(days: 10)),
          ),
          child: const TrialBanner(urgentThreshold: 3),
        ),
      );

      // Normal state — info icon
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

      // Change to urgent (2 days)
      key.currentState!.changeTrialInfo(
        TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('TrialBanner shows expired state when trial ends',
        (tester) async {
      final key = GlobalKey<_TierChangerState>();

      await tester.pumpWidget(
        _TierChanger(
          key: key,
          config: defaultTestConfig,
          initialTier: 'free',
          trialInfo: TrialInfo(
            isTrialing: true,
            endsAt: DateTime.now().add(const Duration(days: 5)),
          ),
          child: const TrialBanner(),
        ),
      );

      expect(find.textContaining('remaining'), findsOneWidget);

      // Expire
      key.currentState!.changeTrialInfo(
        TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      await tester.pump();

      expect(find.textContaining('ended'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 7: allowedTiers deep dive
  // =========================================================================
  group('Edge Cases — allowedTiers specific behaviors', () {
    testWidgets('allowedTiers with single tier — only exact match',
        (tester) async {
      // pro → visible
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['pro'],
          behavior: GuardBehavior.hide,
          child: Text('Pro Only'),
        ),
      ));
      expect(find.text('Pro Only'), findsOneWidget);
    });

    testWidgets('allowedTiers with single tier — higher tier blocked',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['pro'],
          behavior: GuardBehavior.hide,
          child: Text('Pro Only'),
        ),
      ));
      // premium is higher but NOT in the list
      expect(find.text('Pro Only'), findsNothing);
    });

    testWidgets('allowedTiers with single tier — lower tier blocked',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['pro'],
          behavior: GuardBehavior.hide,
          child: Text('Pro Only'),
        ),
      ));
      expect(find.text('Pro Only'), findsNothing);
    });

    testWidgets('allowedTiers with all tiers grants access to everyone',
        (tester) async {
      for (final tier in ['free', 'basic', 'pro', 'premium']) {
        await tester.pumpWidget(buildTestApp(
          currentTier: tier,
          child: const SubscriptionGuard.allowedTiers(
            tierIds: ['free', 'basic', 'pro', 'premium'],
            child: Text('All Access'),
          ),
        ));
        expect(find.text('All Access'), findsOneWidget,
            reason: '$tier should have access');
      }
    });

    testWidgets('allowedTiers with non-adjacent tiers', (tester) async {
      const guard = SubscriptionGuard.allowedTiers(
        tierIds: ['free', 'premium'],
        behavior: GuardBehavior.hide,
        child: Text('Skip Middle'),
      );

      // free → visible
      await tester.pumpWidget(buildTestApp(currentTier: 'free', child: guard));
      expect(find.text('Skip Middle'), findsOneWidget);

      // basic → blocked
      await tester.pumpWidget(buildTestApp(currentTier: 'basic', child: guard));
      expect(find.text('Skip Middle'), findsNothing);

      // pro → blocked
      await tester.pumpWidget(buildTestApp(currentTier: 'pro', child: guard));
      expect(find.text('Skip Middle'), findsNothing);

      // premium → visible
      await tester
          .pumpWidget(buildTestApp(currentTier: 'premium', child: guard));
      expect(find.text('Skip Middle'), findsOneWidget);
    });

    testWidgets('allowedTiers respects behavior parameter', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['pro'],
          behavior: GuardBehavior.blur,
          child: Text('Blurred'),
        ),
      ));

      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('allowedTiers respects lockedBuilder', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard.allowedTiers(
          tierIds: const ['pro'],
          lockedBuilder: (_, __, ___) => const Text('TIER NOT ALLOWED'),
          child: const Text('Content'),
        ),
      ));

      expect(find.text('TIER NOT ALLOWED'), findsOneWidget);
    });

    testWidgets('allowedTiers fires onBlocked when blocked', (tester) async {
      var blocked = false;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard.allowedTiers(
          tierIds: const ['pro'],
          onBlocked: () => blocked = true,
          child: const Text('Content'),
        ),
      ));

      expect(blocked, isTrue);
    });

    testWidgets('allowedTiers does NOT fire onBlocked when allowed',
        (tester) async {
      var blocked = false;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: SubscriptionGuard.allowedTiers(
          tierIds: const ['pro'],
          onBlocked: () => blocked = true,
          child: const Text('Content'),
        ),
      ));

      expect(blocked, isFalse);
    });
  });

  // =========================================================================
  // Group 8: Multiple guards in same tree
  // =========================================================================
  group('Edge Cases — multiple guards in same tree', () {
    testWidgets('nested SubscriptionGuards both evaluate independently',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'basic',
        child: const SubscriptionGuard(
          requiredTier: 'basic',
          child: SubscriptionGuard(
            requiredTier: 'pro',
            behavior: GuardBehavior.hide,
            child: Text('Deep Content'),
          ),
        ),
      ));

      // Outer passes (basic >= basic), inner blocks (basic < pro)
      expect(find.text('Deep Content'), findsNothing);
    });

    testWidgets('nested guards — both pass when tier is high enough',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: const SubscriptionGuard(
          requiredTier: 'basic',
          child: SubscriptionGuard(
            requiredTier: 'pro',
            child: Text('Deep Content'),
          ),
        ),
      ));

      expect(find.text('Deep Content'), findsOneWidget);
    });

    testWidgets(
        'nested guards — outer blocks prevents inner from even building',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.hide,
          child: SubscriptionGuard(
            requiredTier: 'basic',
            child: Text('Inner Content'),
          ),
        ),
      ));

      // Outer hides → inner never builds
      expect(find.text('Inner Content'), findsNothing);
      // The inner SubscriptionGuard widget should not exist in widget tree
      // because hide returns SizedBox.shrink, discarding the entire child
      // subtree.
    });

    testWidgets('sibling guards work independently', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: const Column(
          children: [
            SubscriptionGuard(
              requiredTier: 'free',
              behavior: GuardBehavior.hide,
              child: Text('FREE'),
            ),
            SubscriptionGuard(
              requiredTier: 'pro',
              behavior: GuardBehavior.hide,
              child: Text('PRO'),
            ),
            SubscriptionGuard(
              requiredTier: 'premium',
              behavior: GuardBehavior.hide,
              child: Text('PREMIUM'),
            ),
          ],
        ),
      ));

      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('PREMIUM'), findsNothing);
    });

    testWidgets('mixed guard types work together', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: const Column(
          children: [
            SubscriptionGuard(
              requiredTier: 'pro',
              behavior: GuardBehavior.hide,
              child: Text('TIER GUARD'),
            ),
            SubscriptionGuard.feature(
              featureId: 'advanced_stats', // requires pro
              behavior: GuardBehavior.hide,
              child: Text('FEATURE GUARD'),
            ),
            SubscriptionGuard.allowedTiers(
              tierIds: ['premium'],
              behavior: GuardBehavior.hide,
              child: Text('ALLOWED GUARD'),
            ),
          ],
        ),
      ));

      expect(find.text('TIER GUARD'), findsOneWidget);
      expect(find.text('FEATURE GUARD'), findsOneWidget);
      expect(find.text('ALLOWED GUARD'), findsNothing);
    });
  });

  // =========================================================================
  // Group 9: Many tiers config (stress test)
  // =========================================================================
  group('Edge Cases — many tiers config (stress test)', () {
    final manyTiersConfig = SubscriptionConfig(
      tiers: List.generate(
        10,
        (i) => Tier(id: 'tier_$i', level: i, label: 'Tier $i'),
      ),
      features: {
        for (int i = 0; i < 20; i++) 'feature_$i': 'tier_${i % 10}',
      },
    );

    testWidgets('works with 10 tiers config', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: manyTiersConfig,
        currentTier: 'tier_5',
        child: const Column(
          children: [
            SubscriptionGuard(
              requiredTier: 'tier_3',
              behavior: GuardBehavior.hide,
              child: Text('LOWER'),
            ),
            SubscriptionGuard(
              requiredTier: 'tier_7',
              behavior: GuardBehavior.hide,
              child: Text('HIGHER'),
            ),
          ],
        ),
      ));

      expect(find.text('LOWER'), findsOneWidget); // 5 >= 3
      expect(find.text('HIGHER'), findsNothing); // 5 < 7
    });

    testWidgets('feature gating works with 20 features', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: manyTiersConfig,
        currentTier: 'tier_5',
        child: const Column(
          children: [
            SubscriptionGuard.feature(
              featureId: 'feature_3', // requires tier_3
              behavior: GuardBehavior.hide,
              child: Text('FEAT_3'),
            ),
            SubscriptionGuard.feature(
              featureId: 'feature_7', // requires tier_7
              behavior: GuardBehavior.hide,
              child: Text('FEAT_7'),
            ),
          ],
        ),
      ));

      expect(find.text('FEAT_3'), findsOneWidget);
      expect(find.text('FEAT_7'), findsNothing);
    });

    testWidgets('getAccessibleFeatures returns correct count for middle tier',
        (tester) async {
      final accessible = manyTiersConfig.getAccessibleFeatures('tier_5');
      // tier_5 can access features for tier_0 through tier_5
      // Each tier has 2 features (features 0&10 for tier_0, 1&11 for tier_1, etc.)
      // Tiers 0-5 = 6 tiers × 2 features = 12 features
      expect(accessible.length, 12);
      // Verify specific features
      expect(accessible, contains('feature_0')); // tier_0
      expect(accessible, contains('feature_5')); // tier_5
      expect(accessible, contains('feature_15')); // tier_5 (15 % 10 = 5)
      expect(accessible, isNot(contains('feature_6'))); // tier_6
      expect(accessible, isNot(contains('feature_9'))); // tier_9
    });
  });

  // =========================================================================
  // Group 10: Non-sequential tier levels
  // =========================================================================
  group('Edge Cases — non-sequential tier levels', () {
    final gapConfig = SubscriptionConfig(
      tiers: const [
        Tier(id: 'free', level: 0, label: 'Free'),
        Tier(id: 'starter', level: 10, label: 'Starter'),
        Tier(id: 'business', level: 50, label: 'Business'),
        Tier(id: 'enterprise', level: 100, label: 'Enterprise'),
      ],
      features: const {
        'basic': 'free',
        'analytics': 'starter',
        'api': 'business',
        'sso': 'enterprise',
      },
    );

    testWidgets('hierarchy works with large gaps between levels',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: gapConfig,
        currentTier: 'business', // level 50
        child: const SubscriptionGuard(
          requiredTier: 'starter', // level 10
          child: Text('Analytics'),
        ),
      ));

      expect(find.text('Analytics'), findsOneWidget); // 50 >= 10
    });

    testWidgets('level gap does not grant intermediate access incorrectly',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: gapConfig,
        currentTier: 'starter', // level 10
        child: const SubscriptionGuard(
          requiredTier: 'business', // level 50
          behavior: GuardBehavior.hide,
          child: Text('API'),
        ),
      ));

      expect(find.text('API'), findsNothing); // 10 < 50
    });

    testWidgets('feature gating respects non-sequential levels',
        (tester) async {
      // starter → 'api' requires business (level 50) → blocked
      await tester.pumpWidget(buildTestApp(
        config: gapConfig,
        currentTier: 'starter',
        child: const SubscriptionGuard.feature(
          featureId: 'api',
          behavior: GuardBehavior.hide,
          child: Text('API'),
        ),
      ));
      expect(find.text('API'), findsNothing);

      // enterprise → 'api' requires business (level 50) → visible
      await tester.pumpWidget(buildTestApp(
        config: gapConfig,
        currentTier: 'enterprise',
        child: const SubscriptionGuard.feature(
          featureId: 'api',
          child: Text('API'),
        ),
      ));
      expect(find.text('API'), findsOneWidget);
    });

    testWidgets('tiers sorted correctly regardless of level gaps',
        (tester) async {
      expect(gapConfig.lowestTier.id, 'free');
      expect(gapConfig.lowestTier.level, 0);
      expect(gapConfig.highestTier.id, 'enterprise');
      expect(gapConfig.highestTier.level, 100);
      expect(
        gapConfig.tiers.map((t) => t.id).toList(),
        ['free', 'starter', 'business', 'enterprise'],
      );
    });
  });

  // =========================================================================
  // Group 11: Negative tier levels
  // =========================================================================
  group('Edge Cases — negative tier levels', () {
    final negativeConfig = SubscriptionConfig(
      tiers: const [
        Tier(id: 'banned', level: -1, label: 'Banned'),
        Tier(id: 'free', level: 0, label: 'Free'),
        Tier(id: 'pro', level: 1, label: 'Pro'),
      ],
    );

    testWidgets('negative level tier has less access than level 0',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: negativeConfig,
        currentTier: 'banned', // level -1
        child: const SubscriptionGuard(
          requiredTier: 'free', // level 0
          behavior: GuardBehavior.hide,
          child: Text('Free Content'),
        ),
      ));

      expect(find.text('Free Content'), findsNothing); // -1 < 0
    });

    testWidgets('level 0 tier can access negative level tier', (tester) async {
      await tester.pumpWidget(buildTestApp(
        config: negativeConfig,
        currentTier: 'free', // level 0
        child: const SubscriptionGuard(
          requiredTier: 'banned', // level -1
          child: Text('Banned Content'),
        ),
      ));

      expect(find.text('Banned Content'), findsOneWidget); // 0 >= -1
    });

    testWidgets('config sorts negative levels correctly', (tester) async {
      expect(negativeConfig.lowestTier.id, 'banned');
      expect(negativeConfig.lowestTier.level, -1);
      expect(negativeConfig.highestTier.id, 'pro');
      expect(negativeConfig.highestTier.level, 1);
      expect(
        negativeConfig.tiers.map((t) => t.level).toList(),
        [-1, 0, 1],
      );
    });
  });
}
