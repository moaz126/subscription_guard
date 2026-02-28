// Tests for SubscriptionGuard widget — gating behavior per tier and guard
// behavior modes, lockedBuilder priority, feature/allowedTiers constructors,
// reactivity, trial support, callbacks, DefaultLockedWidget, TrialBanner,
// and SubscriptionGuardScope programmatic access.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_guard/subscription_guard.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Reusable helper that wraps a widget with MaterialApp +
/// SubscriptionGuardProvider so SubscriptionGuard widgets can find the scope.
Widget buildTestApp({
  required String currentTier,
  required Widget child,
  SubscriptionConfig? config,
  TrialInfo? trialInfo,
  GuardBehavior defaultBehavior = GuardBehavior.replace,
  Widget Function(BuildContext, Tier, Tier)? defaultLockedBuilder,
  void Function(Tier)? onUpgradeRequested,
  void Function(String?, Tier, Tier)? onFeatureBlocked,
}) {
  return MaterialApp(
    home: SubscriptionGuardProvider(
      config: config ?? defaultTestConfig,
      currentTier: currentTier,
      trialInfo: trialInfo ?? const TrialInfo.none(),
      defaultBehavior: defaultBehavior,
      defaultLockedBuilder: defaultLockedBuilder,
      onUpgradeRequested: onUpgradeRequested,
      onFeatureBlocked: onFeatureBlocked,
      child: Scaffold(body: child),
    ),
  );
}

/// Default test config used across most tests.
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

/// A StatefulWidget wrapper that lets tests change currentTier via setState.
class _TierSwitcher extends StatefulWidget {
  const _TierSwitcher({
    super.key,
    required this.initialTier,
    required this.child,
    this.config,
  });
  final String initialTier;
  final Widget child;
  final SubscriptionConfig? config;

  @override
  State<_TierSwitcher> createState() => _TierSwitcherState();
}

class _TierSwitcherState extends State<_TierSwitcher> {
  late String _currentTier;
  SubscriptionConfig? _config;

  @override
  void initState() {
    super.initState();
    _currentTier = widget.initialTier;
    _config = widget.config;
  }

  void changeTier(String tier) => setState(() => _currentTier = tier);
  void changeConfig(SubscriptionConfig config) =>
      setState(() => _config = config);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SubscriptionGuardProvider(
        config: _config ?? defaultTestConfig,
        currentTier: _currentTier,
        child: Scaffold(body: widget.child),
      ),
    );
  }
}

/// A widget that tracks whether its build method was ever called.
class _BuildTracker extends StatelessWidget {
  const _BuildTracker({required this.tracker});
  final List<bool> tracker;

  @override
  Widget build(BuildContext context) {
    tracker.add(true);
    return const Text('Tracked');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  // =========================================================================
  // Group 1: SubscriptionGuard — basic tier gating
  // =========================================================================
  group('SubscriptionGuard — basic tier gating', () {
    testWidgets('shows child when current tier matches required tier',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          child: Text('Premium Content'),
        ),
      ));

      expect(find.text('Premium Content'), findsOneWidget);
    });

    testWidgets('shows child when current tier is higher than required',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          child: Text('Pro Content'),
        ),
      ));

      expect(find.text('Pro Content'), findsOneWidget);
    });

    testWidgets(
        'shows child when current tier is higher than required by multiple levels',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: const SubscriptionGuard(
          requiredTier: 'free',
          child: Text('Free Content'),
        ),
      ));

      expect(find.text('Free Content'), findsOneWidget);
    });

    testWidgets('hides child when current tier is lower than required',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.hide,
          child: Text('Premium Content'),
        ),
      ));

      expect(find.text('Premium Content'), findsNothing);
    });

    testWidgets('free tier can access free-required guard', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'free',
          child: Text('Free Feature'),
        ),
      ));

      expect(find.text('Free Feature'), findsOneWidget);
    });

    testWidgets('lowest tier cannot access highest tier guard', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'premium',
          behavior: GuardBehavior.hide,
          child: Text('Top Feature'),
        ),
      ));

      expect(find.text('Top Feature'), findsNothing);
    });
  });

  // =========================================================================
  // Group 2: SubscriptionGuard — GuardBehavior modes
  // =========================================================================
  group('SubscriptionGuard — GuardBehavior.hide', () {
    testWidgets('completely removes child from tree', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.hide,
          child: Text('Premium Content'),
        ),
      ));

      expect(find.text('Premium Content'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('child widget does NOT build at all', (tester) async {
      final tracker = <bool>[];

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.hide,
          child: _BuildTracker(tracker: tracker),
        ),
      ));

      expect(tracker, isEmpty);
    });
  });

  group('SubscriptionGuard — GuardBehavior.disable', () {
    testWidgets('shows child but wrapped in IgnorePointer', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.disable,
          child: Text('Disabled Content'),
        ),
      ));

      expect(find.text('Disabled Content'), findsOneWidget);

      // Find the nearest IgnorePointer ancestor of our content text
      final ipFinder = find.ancestor(
        of: find.text('Disabled Content'),
        matching: find.byType(IgnorePointer),
      );
      // The first (closest) IgnorePointer is the one from SubscriptionGuard
      final ignorePointer = tester.widget<IgnorePointer>(ipFinder.first);
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets('shows child with reduced opacity', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.disable,
          child: Text('Disabled Content'),
        ),
      ));

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, closeTo(0.4, 0.01));
    });

    testWidgets('child is not tappable when disabled', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.disable,
          child: ElevatedButton(
            onPressed: () => tapped = true,
            child: const Text('Tap Me'),
          ),
        ),
      ));

      await tester.tap(find.text('Tap Me'), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse);
    });
  });

  group('SubscriptionGuard — GuardBehavior.replace', () {
    testWidgets(
        'shows DefaultLockedWidget when no custom lockedBuilder provided',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.replace,
          child: Text('Premium Content'),
        ),
      ));

      expect(find.byType(DefaultLockedWidget), findsOneWidget);
      expect(find.text('Premium Content'), findsNothing);
    });

    testWidgets('shows required tier label in default locked widget',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.replace,
          child: Text('Content'),
        ),
      ));

      // DefaultLockedWidget shows "Upgrade to Pro to unlock this feature" and
      // an OutlinedButton "Upgrade to Pro".
      expect(find.textContaining('Pro'), findsWidgets);
    });

    testWidgets('does NOT show child content when replaced', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.replace,
          child: Text('Premium Content'),
        ),
      ));

      expect(find.text('Premium Content'), findsNothing);
    });
  });

  group('SubscriptionGuard — GuardBehavior.blur', () {
    testWidgets('shows child with ImageFiltered blur', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          child: Text('Blurred Content'),
        ),
      ));

      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('shows lock overlay on top of blurred child', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          child: Text('Blurred Content'),
        ),
      ));

      // blur mode uses a Stack containing ImageFiltered + Positioned overlay
      expect(find.byType(Stack), findsWidgets);
      // The child text IS in the tree (just blurred)
      expect(find.text('Blurred Content'), findsOneWidget);
      // ConstrainedBox enforcing minHeight is present
      expect(find.byType(ConstrainedBox), findsWidgets);
    });

    testWidgets('enforces blurMinHeight on child', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          blurMinHeight: 150,
          child: SizedBox(height: 40, child: Text('Tiny')),
        ),
      ));

      // Find the ConstrainedBox that wraps the blurred child
      final constrainedBoxes = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where((cb) => cb.constraints.minHeight == 150);
      expect(constrainedBoxes, isNotEmpty);
    });

    testWidgets('custom blurMinHeight is respected', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          blurMinHeight: 200,
          child: SizedBox(height: 40, child: Text('Small')),
        ),
      ));

      final constrainedBoxes = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where((cb) => cb.constraints.minHeight == 200);
      expect(constrainedBoxes, isNotEmpty);
    });

    testWidgets('shows full overlay for tall child (>= 120)', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          child: SizedBox(height: 200, child: Text('Tall content')),
        ),
      ));

      // Full overlay should show DefaultLockedWidget with upgrade button
      expect(find.byType(DefaultLockedWidget), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
    });

    testWidgets('shows compact overlay for medium child (60-119)',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          blurMinHeight: 80, // Don't force expand beyond 80
          child: SizedBox(height: 80, child: Text('Medium')),
        ),
      ));

      // Compact overlay shows "Upgrade to Pro" text in a Row
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      // But no DefaultLockedWidget (that's the full overlay)
      expect(find.byType(DefaultLockedWidget), findsNothing);
    });

    testWidgets('shows minimal overlay for very short child (< 60)',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          blurMinHeight: 40, // Don't force expand
          child: SizedBox(height: 40, child: Text('Tiny')),
        ),
      ));

      // Minimal overlay: just a lock icon, no text
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byType(DefaultLockedWidget), findsNothing);
    });

    testWidgets('compact overlay is tappable and calls requestUpgrade',
        (tester) async {
      Tier? upgradedTier;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onUpgradeRequested: (tier) => upgradedTier = tier,
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          blurMinHeight: 80,
          child: SizedBox(height: 80, child: Text('Medium')),
        ),
      ));

      // Tap the compact overlay GestureDetector
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();

      expect(upgradedTier, isNotNull);
      expect(upgradedTier!.id, 'pro');
    });

    testWidgets('minimal overlay is tappable and calls requestUpgrade',
        (tester) async {
      Tier? upgradedTier;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onUpgradeRequested: (tier) => upgradedTier = tier,
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          blurMinHeight: 40,
          child: SizedBox(height: 40, child: Text('Tiny')),
        ),
      ));

      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();

      expect(upgradedTier, isNotNull);
      expect(upgradedTier!.id, 'pro');
    });

    testWidgets('uses lockedBuilder for full overlay only', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          lockedBuilder: (_, __, ___) => const Text('CUSTOM LOCKED'),
          child: const SizedBox(height: 200, child: Text('Tall content')),
        ),
      ));

      // Full height — uses lockedBuilder
      expect(find.text('CUSTOM LOCKED'), findsOneWidget);
      expect(find.byType(DefaultLockedWidget), findsNothing);
    });

    testWidgets('does not use lockedBuilder for compact overlay',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          blurMinHeight: 80,
          lockedBuilder: (_, __, ___) => const Text('CUSTOM LOCKED'),
          child: const SizedBox(height: 80, child: Text('Medium')),
        ),
      ));

      // Compact height — ignores lockedBuilder, uses built-in compact
      expect(find.text('CUSTOM LOCKED'), findsNothing);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
    });

    testWidgets('default blurMinHeight is 180', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.blur,
          child: SizedBox(height: 30, child: Text('Short')),
        ),
      ));

      // Default blurMinHeight 180 means ConstrainedBox(minHeight: 180)
      final constrainedBoxes = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where((cb) => cb.constraints.minHeight == 180);
      expect(constrainedBoxes, isNotEmpty);
      // With minHeight 120, the full overlay should appear
      expect(find.byType(DefaultLockedWidget), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 2b: SubscriptionGuard — adaptive blur with feature constructor
  // =========================================================================
  group('SubscriptionGuard — blur with feature constructor', () {
    testWidgets('feature constructor supports blurMinHeight', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: 'advanced_stats',
          behavior: GuardBehavior.blur,
          blurMinHeight: 80,
          child: SizedBox(height: 80, child: Text('Stats')),
        ),
      ));

      // Compact overlay with feature-resolved tier
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.byType(DefaultLockedWidget), findsNothing);
    });

    testWidgets('allowedTiers constructor supports blurMinHeight',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['pro'],
          behavior: GuardBehavior.blur,
          blurMinHeight: 80,
          child: SizedBox(height: 80, child: Text('Pro Only')),
        ),
      ));

      // Compact overlay — allowedTiers resolves to highest tier in list
      expect(find.byType(DefaultLockedWidget), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 3: SubscriptionGuard — lockedBuilder priority
  // =========================================================================
  group('SubscriptionGuard — lockedBuilder priority', () {
    testWidgets('widget-level lockedBuilder takes highest priority',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        defaultLockedBuilder: (_, __, ___) => const Text('PROVIDER LOCKED'),
        child: SubscriptionGuard(
          requiredTier: 'pro',
          lockedBuilder: (_, __, ___) => const Text('WIDGET LOCKED'),
          child: const Text('Content'),
        ),
      ));

      expect(find.text('WIDGET LOCKED'), findsOneWidget);
      expect(find.text('PROVIDER LOCKED'), findsNothing);
    });

    testWidgets('provider-level defaultLockedBuilder used when widget has none',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        defaultLockedBuilder: (_, __, ___) => const Text('PROVIDER LOCKED'),
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          child: Text('Content'),
        ),
      ));

      expect(find.text('PROVIDER LOCKED'), findsOneWidget);
    });

    testWidgets(
        'DefaultLockedWidget used when neither widget nor provider has lockedBuilder',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          child: Text('Content'),
        ),
      ));

      expect(find.byType(DefaultLockedWidget), findsOneWidget);
    });

    testWidgets('lockedBuilder receives correct requiredTier and currentTier',
        (tester) async {
      Tier? capturedRequired;
      Tier? capturedCurrent;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard(
          requiredTier: 'pro',
          lockedBuilder: (context, required, current) {
            capturedRequired = required;
            capturedCurrent = current;
            return const Text('LOCKED');
          },
          child: const Text('Content'),
        ),
      ));

      expect(capturedRequired?.id, 'pro');
      expect(capturedCurrent?.id, 'free');
    });
  });

  // =========================================================================
  // Group 4: SubscriptionGuard — behavior fallback
  // =========================================================================
  group('SubscriptionGuard — behavior fallback', () {
    testWidgets('uses provider defaultBehavior when widget behavior is null',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        defaultBehavior: GuardBehavior.hide,
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          // behavior is null — falls back to provider default (hide)
          child: Text('Content'),
        ),
      ));

      // hide → SizedBox.shrink, no child, no DefaultLockedWidget
      expect(find.text('Content'), findsNothing);
      expect(find.byType(DefaultLockedWidget), findsNothing);
    });

    testWidgets('widget behavior overrides provider defaultBehavior',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        defaultBehavior: GuardBehavior.hide,
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.replace,
          child: Text('Content'),
        ),
      ));

      // Widget says replace → DefaultLockedWidget, NOT hidden
      expect(find.byType(DefaultLockedWidget), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 5: SubscriptionGuard.feature() — feature-based gating
  // =========================================================================
  group('SubscriptionGuard.feature()', () {
    testWidgets('shows child when user has access to feature tier',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: 'basic_stats', // requires 'free'
          child: Text('Basic Stats'),
        ),
      ));

      expect(find.text('Basic Stats'), findsOneWidget);
    });

    testWidgets('shows child when user tier is higher than feature tier',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: const SubscriptionGuard.feature(
          featureId: 'advanced_stats', // requires 'pro'
          child: Text('Advanced Stats'),
        ),
      ));

      expect(find.text('Advanced Stats'), findsOneWidget);
    });

    testWidgets('blocks when user tier is lower than feature tier',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: 'export_pdf', // requires 'pro'
          behavior: GuardBehavior.hide,
          child: Text('Export'),
        ),
      ));

      expect(find.text('Export'), findsNothing);
    });

    testWidgets('blocks when free user tries premium feature', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: 'team_management', // requires 'premium'
          behavior: GuardBehavior.hide,
          child: Text('Teams'),
        ),
      ));

      expect(find.text('Teams'), findsNothing);
    });

    testWidgets('respects behavior parameter', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: 'export_pdf',
          behavior: GuardBehavior.disable,
          child: Text('Export'),
        ),
      ));

      expect(find.text('Export'), findsOneWidget);
      final ipFinder = find.ancestor(
        of: find.text('Export'),
        matching: find.byType(IgnorePointer),
      );
      final ip = tester.widget<IgnorePointer>(ipFinder.first);
      expect(ip.ignoring, isTrue);
    });

    testWidgets('respects custom lockedBuilder', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard.feature(
          featureId: 'export_pdf',
          lockedBuilder: (_, __, ___) => const Text('CUSTOM LOCK'),
          child: const Text('Export'),
        ),
      ));

      expect(find.text('CUSTOM LOCK'), findsOneWidget);
    });

    testWidgets('throws error for non-existent feature id', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.feature(
          featureId: 'nonexistent_feature',
          child: Text('Never'),
        ),
      ));

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(
        (error as FlutterError).toString(),
        contains('nonexistent_feature'),
      );
    });
  });

  // =========================================================================
  // Group 6: SubscriptionGuard.allowedTiers() — specific tier gating
  // =========================================================================
  group('SubscriptionGuard.allowedTiers()', () {
    testWidgets('shows child when current tier is in allowed list',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['pro', 'premium'],
          child: Text('Allowed'),
        ),
      ));

      expect(find.text('Allowed'), findsOneWidget);
    });

    testWidgets('shows child for second tier in allowed list', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['pro', 'premium'],
          child: Text('Allowed'),
        ),
      ));

      expect(find.text('Allowed'), findsOneWidget);
    });

    testWidgets('blocks when current tier is NOT in allowed list',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['pro', 'premium'],
          behavior: GuardBehavior.hide,
          child: Text('Blocked'),
        ),
      ));

      expect(find.text('Blocked'), findsNothing);
    });

    testWidgets(
        'blocks higher tier if not in allowed list (NOT hierarchy-based)',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['basic'],
          behavior: GuardBehavior.hide,
          child: Text('Basic Only'),
        ),
      ));

      // premium is HIGHER than basic but NOT in the list → blocked
      expect(find.text('Basic Only'), findsNothing);
    });

    testWidgets('blocks lower tier even if higher tier is allowed',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: const SubscriptionGuard.allowedTiers(
          tierIds: ['premium'],
          behavior: GuardBehavior.hide,
          child: Text('Premium Only'),
        ),
      ));

      expect(find.text('Premium Only'), findsNothing);
    });
  });

  // =========================================================================
  // Group 7: SubscriptionGuard — tier change reactivity
  // =========================================================================
  group('SubscriptionGuard — tier change reactivity', () {
    testWidgets('automatically shows child when tier upgrades from free to pro',
        (tester) async {
      final key = GlobalKey<_TierSwitcherState>();

      await tester.pumpWidget(
        _TierSwitcher(
          key: key,
          initialTier: 'free',
          child: const SubscriptionGuard(
            requiredTier: 'pro',
            behavior: GuardBehavior.hide,
            child: Text('Pro Content'),
          ),
        ),
      );

      expect(find.text('Pro Content'), findsNothing);

      // Upgrade to pro
      key.currentState!.changeTier('pro');
      await tester.pump();

      expect(find.text('Pro Content'), findsOneWidget);
    });

    testWidgets(
        'automatically hides child when tier downgrades from pro to free',
        (tester) async {
      final key = GlobalKey<_TierSwitcherState>();

      await tester.pumpWidget(
        _TierSwitcher(
          key: key,
          initialTier: 'pro',
          child: const SubscriptionGuard(
            requiredTier: 'pro',
            behavior: GuardBehavior.hide,
            child: Text('Pro Content'),
          ),
        ),
      );

      expect(find.text('Pro Content'), findsOneWidget);

      // Downgrade to free
      key.currentState!.changeTier('free');
      await tester.pump();

      expect(find.text('Pro Content'), findsNothing);
    });

    testWidgets('multiple guards update simultaneously on tier change',
        (tester) async {
      final key = GlobalKey<_TierSwitcherState>();

      await tester.pumpWidget(
        _TierSwitcher(
          key: key,
          initialTier: 'free',
          child: const Column(
            children: [
              SubscriptionGuard(
                requiredTier: 'basic',
                behavior: GuardBehavior.hide,
                child: Text('Basic Feature'),
              ),
              SubscriptionGuard(
                requiredTier: 'pro',
                behavior: GuardBehavior.hide,
                child: Text('Pro Feature'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Basic Feature'), findsNothing);
      expect(find.text('Pro Feature'), findsNothing);

      // Upgrade to pro → both should show
      key.currentState!.changeTier('pro');
      await tester.pump();

      expect(find.text('Basic Feature'), findsOneWidget);
      expect(find.text('Pro Feature'), findsOneWidget);
    });

    testWidgets('guard re-evaluates when config changes', (tester) async {
      final key = GlobalKey<_TierSwitcherState>();

      // Config where 'export' needs 'pro'
      final configV1 = SubscriptionConfig(
        tiers: const [
          Tier(id: 'free', level: 0, label: 'Free'),
          Tier(id: 'basic', level: 1, label: 'Basic'),
          Tier(id: 'pro', level: 2, label: 'Pro'),
        ],
        features: const {'export': 'pro'},
      );

      await tester.pumpWidget(
        _TierSwitcher(
          key: key,
          initialTier: 'basic',
          config: configV1,
          child: const SubscriptionGuard.feature(
            featureId: 'export',
            behavior: GuardBehavior.hide,
            child: Text('Export Feature'),
          ),
        ),
      );

      expect(find.text('Export Feature'), findsNothing);

      // Change config so 'export' only needs 'basic'
      final configV2 = SubscriptionConfig(
        tiers: const [
          Tier(id: 'free', level: 0, label: 'Free'),
          Tier(id: 'basic', level: 1, label: 'Basic'),
          Tier(id: 'pro', level: 2, label: 'Pro'),
        ],
        features: const {'export': 'basic'},
      );
      key.currentState!.changeConfig(configV2);
      await tester.pump();

      expect(find.text('Export Feature'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 8: SubscriptionGuard — trial support
  // =========================================================================
  group('SubscriptionGuard — trial support', () {
    testWidgets(
        'grants access during active trial when allowDuringTrial is true',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 5)),
        ),
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          allowDuringTrial: true,
          child: Text('Trial Content'),
        ),
      ));

      expect(find.text('Trial Content'), findsOneWidget);
    });

    testWidgets('blocks access during trial when allowDuringTrial is false',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 5)),
        ),
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          allowDuringTrial: false,
          behavior: GuardBehavior.hide,
          child: Text('Trial Content'),
        ),
      ));

      expect(find.text('Trial Content'), findsNothing);
    });

    testWidgets('blocks access when trial is expired', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          allowDuringTrial: true,
          behavior: GuardBehavior.hide,
          child: Text('Expired Trial Content'),
        ),
      ));

      // Trial expired → isTrialing is true but isActive is false → blocked
      expect(find.text('Expired Trial Content'), findsNothing);
    });
  });

  // =========================================================================
  // Group 9: SubscriptionGuard — callbacks
  // =========================================================================
  group('SubscriptionGuard — callbacks', () {
    testWidgets('onBlocked callback fires when guard blocks user',
        (tester) async {
      var blockedCalled = false;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: SubscriptionGuard(
          requiredTier: 'pro',
          onBlocked: () => blockedCalled = true,
          child: const Text('Content'),
        ),
      ));

      expect(blockedCalled, isTrue);
    });

    testWidgets('onBlocked does NOT fire when access is granted',
        (tester) async {
      var blockedCalled = false;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: SubscriptionGuard(
          requiredTier: 'pro',
          onBlocked: () => blockedCalled = true,
          child: const Text('Content'),
        ),
      ));

      expect(blockedCalled, isFalse);
    });

    testWidgets('onFeatureBlocked on provider fires when guard blocks',
        (tester) async {
      String? blockedFeature;
      Tier? blockedRequired;
      Tier? blockedCurrent;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onFeatureBlocked: (feature, required, current) {
          blockedFeature = feature;
          blockedRequired = required;
          blockedCurrent = current;
        },
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          child: Text('Content'),
        ),
      ));

      // featureId is null for the default constructor (tier-based guard)
      expect(blockedFeature, isNull);
      expect(blockedRequired?.id, 'pro');
      expect(blockedCurrent?.id, 'free');
    });

    testWidgets(
        'onUpgradeRequested fires when upgrade button tapped in default locked widget',
        (tester) async {
      Tier? requestedTier;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onUpgradeRequested: (tier) => requestedTier = tier,
        child: const SubscriptionGuard(
          requiredTier: 'pro',
          behavior: GuardBehavior.replace,
          child: Text('Content'),
        ),
      ));

      // DefaultLockedWidget shows an OutlinedButton "Upgrade to Pro"
      final upgradeButton =
          find.widgetWithText(OutlinedButton, 'Upgrade to Pro');
      expect(upgradeButton, findsOneWidget);

      await tester.tap(upgradeButton);
      await tester.pump();

      expect(requestedTier?.id, 'pro');
    });
  });

  // =========================================================================
  // Group 10: DefaultLockedWidget
  // =========================================================================
  group('DefaultLockedWidget', () {
    const requiredTier = Tier(id: 'pro', level: 2, label: 'Pro');
    const currentTier = Tier(id: 'free', level: 0, label: 'Free');

    Widget wrapStandalone(DefaultLockedWidget widget) {
      return MaterialApp(home: Scaffold(body: widget));
    }

    testWidgets('shows lock icon', (tester) async {
      await tester.pumpWidget(wrapStandalone(const DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
      )));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows required tier label in message', (tester) async {
      await tester.pumpWidget(wrapStandalone(const DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
      )));

      expect(find.textContaining('Pro'), findsWidgets);
    });

    testWidgets('shows upgrade button when onUpgradePressed is provided',
        (tester) async {
      await tester.pumpWidget(wrapStandalone(DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
        onUpgradePressed: () {},
      )));

      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('hides upgrade button when onUpgradePressed is null',
        (tester) async {
      await tester.pumpWidget(wrapStandalone(const DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
        // onUpgradePressed is null by default
      )));

      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('calls onUpgradePressed when button tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(wrapStandalone(DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
        onUpgradePressed: () => tapped = true,
      )));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('compact mode shows single row layout', (tester) async {
      await tester.pumpWidget(wrapStandalone(const DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
        compact: true,
      )));

      // Compact mode uses a Row for the layout
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('normal mode shows column layout', (tester) async {
      await tester.pumpWidget(wrapStandalone(const DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
      )));

      // Normal mode uses a Column for the layout
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('custom message overrides default', (tester) async {
      await tester.pumpWidget(wrapStandalone(const DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
        message: 'Custom lock message',
      )));

      expect(find.text('Custom lock message'), findsOneWidget);
    });

    testWidgets('custom icon is used', (tester) async {
      await tester.pumpWidget(wrapStandalone(const DefaultLockedWidget(
        requiredTier: requiredTier,
        currentTier: currentTier,
        icon: Icons.star,
      )));

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });
  });

  // =========================================================================
  // Group 11: TrialBanner
  // =========================================================================
  group('TrialBanner', () {
    testWidgets(
        'shows nothing when not trialing and showWhenNotTrialing is false',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: const TrialInfo.none(),
        child: const TrialBanner(),
      ));

      // Should render SizedBox.shrink — no visible trial text
      expect(find.textContaining('trial'), findsNothing);
      expect(find.textContaining('Trial'), findsNothing);
    });

    testWidgets('shows banner when actively trialing', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 10)),
        ),
        child: const TrialBanner(),
      ));

      expect(find.textContaining('remaining'), findsOneWidget);
    });

    testWidgets('shows urgent style when days remaining <= urgentThreshold',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 2)),
        ),
        child: const TrialBanner(urgentThreshold: 3),
      ));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('shows expired message when trial has ended', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        child: const TrialBanner(),
      ));

      expect(find.textContaining('ended'), findsOneWidget);
    });

    testWidgets('handles singular day correctly', (tester) async {
      // Create endsAt that is ~1.5 days from now so daysRemaining == 1
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(hours: 36)),
        ),
        child: const TrialBanner(urgentThreshold: 3),
      ));

      // Should say "1 day" not "1 days"
      expect(find.textContaining('1 day'), findsOneWidget);
      // Make sure it doesn't say "1 days"
      expect(find.textContaining('1 days'), findsNothing);
    });

    testWidgets('custom builder overrides default UI', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 5)),
        ),
        child: TrialBanner(
          builder: (context, trialInfo) =>
              Text('CUSTOM TRIAL: ${trialInfo.daysRemaining}'),
        ),
      ));

      expect(find.textContaining('CUSTOM TRIAL'), findsOneWidget);
    });

    testWidgets('onTap callback fires when banner tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 5)),
        ),
        child: TrialBanner(
          onTap: () => tapped = true,
        ),
      ));

      // onTap wraps the banner in a GestureDetector
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows banner for trial with no end date', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: const TrialInfo(isTrialing: true),
        child: const TrialBanner(),
      ));

      // Should show generic "on a trial" message, no days count
      expect(find.textContaining('trial'), findsWidgets);
    });
  });

  // =========================================================================
  // Group 12: SubscriptionGuardScope — programmatic access
  // =========================================================================
  group('SubscriptionGuardScope — programmatic access', () {
    testWidgets('of(context) returns scope with correct currentTier',
        (tester) async {
      Tier? foundTier;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(
          builder: (context) {
            final scope = SubscriptionGuardScope.of(context);
            foundTier = scope.currentTier;
            return const SizedBox.shrink();
          },
        ),
      ));

      expect(foundTier?.id, 'pro');
    });

    testWidgets('hasAccess returns true for accessible tier', (tester) async {
      bool? result;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(
          builder: (context) {
            final scope = SubscriptionGuardScope.of(context);
            result = scope.hasAccess('basic');
            return const SizedBox.shrink();
          },
        ),
      ));

      expect(result, isTrue);
    });

    testWidgets('hasAccess returns false for inaccessible tier',
        (tester) async {
      bool? result;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(
          builder: (context) {
            final scope = SubscriptionGuardScope.of(context);
            result = scope.hasAccess('pro');
            return const SizedBox.shrink();
          },
        ),
      ));

      expect(result, isFalse);
    });

    testWidgets('hasFeatureAccess returns correct results', (tester) async {
      bool? advancedStats;
      bool? teamManagement;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(
          builder: (context) {
            final scope = SubscriptionGuardScope.of(context);
            advancedStats = scope.hasFeatureAccess('advanced_stats');
            teamManagement = scope.hasFeatureAccess('team_management');
            return const SizedBox.shrink();
          },
        ),
      ));

      expect(advancedStats, isTrue); // pro can access pro features
      expect(teamManagement, isFalse); // pro cannot access premium features
    });

    testWidgets('accessibleFeatures returns correct list', (tester) async {
      List<String>? features;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(
          builder: (context) {
            final scope = SubscriptionGuardScope.of(context);
            features = scope.accessibleFeatures;
            return const SizedBox.shrink();
          },
        ),
      ));

      expect(
        features,
        unorderedEquals(['basic_stats', 'advanced_stats', 'export_pdf']),
      );
      expect(features, isNot(contains('team_management')));
    });

    testWidgets('throws helpful error when no provider in tree',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // This should throw — no SubscriptionGuardProvider above
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Access SubscriptionGuardScope.of from a context with no provider
      late FlutterError caughtError;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              try {
                SubscriptionGuardScope.of(context);
              } on FlutterError catch (e) {
                caughtError = e;
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(caughtError.toString(), contains('SubscriptionGuardProvider'));
    });
  });
}
