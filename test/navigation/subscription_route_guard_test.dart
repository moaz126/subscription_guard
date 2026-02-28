// Tests for subscription route guard — redirect logic and manual access checks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_guard/subscription_guard.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Default 4-tier config used across all navigation tests.
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

/// Wraps a child widget with MaterialApp + SubscriptionGuardProvider.
Widget buildTestApp({
  required String currentTier,
  required Widget child,
  SubscriptionConfig? config,
  TrialInfo? trialInfo,
  GuardBehavior defaultBehavior = GuardBehavior.replace,
  void Function(Tier)? onUpgradeRequested,
  void Function(String?, Tier, Tier)? onFeatureBlocked,
  Map<String, WidgetBuilder>? routes,
}) {
  return MaterialApp(
    routes: routes ?? const {},
    home: SubscriptionGuardProvider(
      config: config ?? defaultTestConfig,
      currentTier: currentTier,
      trialInfo: trialInfo ?? const TrialInfo.none(),
      defaultBehavior: defaultBehavior,
      onUpgradeRequested: onUpgradeRequested,
      onFeatureBlocked: onFeatureBlocked,
      child: Scaffold(body: child),
    ),
  );
}

/// Builds a MaterialApp with named routes + SubscriptionGuardProvider at the
/// home route. Used by pushNamedGuarded tests.
Widget buildRoutedApp({
  required String currentTier,
  required Widget homeChild,
  required Map<String, WidgetBuilder> routes,
  TrialInfo? trialInfo,
  void Function(Tier)? onUpgradeRequested,
  void Function(String?, Tier, Tier)? onFeatureBlocked,
}) {
  return MaterialApp(
    routes: {
      '/': (_) => SubscriptionGuardProvider(
            config: defaultTestConfig,
            currentTier: currentTier,
            trialInfo: trialInfo ?? const TrialInfo.none(),
            onUpgradeRequested: onUpgradeRequested,
            onFeatureBlocked: onFeatureBlocked,
            child: Scaffold(body: homeChild),
          ),
      ...routes,
    },
  );
}

/// Wraps a child with SubscriptionGuardProvider *above* MaterialApp so that
/// pushed routes (like SubscriptionPageRoute) can still find the scope.
Widget buildPageRouteApp({
  required String currentTier,
  required Widget child,
  TrialInfo? trialInfo,
  void Function(Tier)? onUpgradeRequested,
  void Function(String?, Tier, Tier)? onFeatureBlocked,
}) {
  return SubscriptionGuardProvider(
    config: defaultTestConfig,
    currentTier: currentTier,
    trialInfo: trialInfo ?? const TrialInfo.none(),
    onUpgradeRequested: onUpgradeRequested,
    onFeatureBlocked: onFeatureBlocked,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  // =========================================================================
  // Group 1 — RouteAccessResult
  // =========================================================================
  group('RouteAccessResult', () {
    test('hasAccess true when access granted', () {
      const result = RouteAccessResult(
        hasAccess: true,
        currentTier: Tier(id: 'pro', level: 2, label: 'Pro'),
        requiredTier: Tier(id: 'basic', level: 1, label: 'Basic'),
        isTrialing: false,
      );
      expect(result.hasAccess, isTrue);
      expect(result.isBlocked, isFalse);
    });

    test('isBlocked is inverse of hasAccess', () {
      const blocked = RouteAccessResult(
        hasAccess: false,
        currentTier: Tier(id: 'free', level: 0, label: 'Free'),
        requiredTier: Tier(id: 'pro', level: 2, label: 'Pro'),
        isTrialing: false,
      );
      expect(blocked.isBlocked, isTrue);
      expect(blocked.hasAccess, isFalse);

      const allowed = RouteAccessResult(
        hasAccess: true,
        currentTier: Tier(id: 'pro', level: 2, label: 'Pro'),
        isTrialing: false,
      );
      expect(allowed.isBlocked, isFalse);
      expect(allowed.hasAccess, isTrue);
    });

    test('holds correct tier information', () {
      const result = RouteAccessResult(
        hasAccess: false,
        currentTier: Tier(id: 'free', level: 0, label: 'Free'),
        requiredTier: Tier(id: 'premium', level: 3, label: 'Premium'),
        isTrialing: false,
      );
      expect(result.currentTier.id, 'free');
      expect(result.requiredTier?.id, 'premium');
      expect(result.requiredTier?.level, 3);
    });

    test('requiredTier can be null', () {
      const result = RouteAccessResult(
        hasAccess: true,
        currentTier: Tier(id: 'pro', level: 2, label: 'Pro'),
        isTrialing: false,
      );
      expect(result.requiredTier, isNull);
      expect(result.hasAccess, isTrue);
    });

    test('isTrialing reflects trial state', () {
      const trialing = RouteAccessResult(
        hasAccess: true,
        currentTier: Tier(id: 'free', level: 0, label: 'Free'),
        requiredTier: Tier(id: 'pro', level: 2, label: 'Pro'),
        isTrialing: true,
      );
      expect(trialing.isTrialing, isTrue);

      const notTrialing = RouteAccessResult(
        hasAccess: false,
        currentTier: Tier(id: 'free', level: 0, label: 'Free'),
        isTrialing: false,
      );
      expect(notTrialing.isTrialing, isFalse);
    });
  });

  // =========================================================================
  // Group 2 — SubscriptionRouteGuard.checkAccess
  // =========================================================================
  group('SubscriptionRouteGuard.checkAccess', () {
    testWidgets('returns hasAccess true when tier is sufficient',
        (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkAccess(
            context,
            requiredTier: 'basic',
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isTrue);
    });

    testWidgets('returns hasAccess true when tier matches exactly',
        (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkAccess(
            context,
            requiredTier: 'pro',
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isTrue);
    });

    testWidgets('returns hasAccess false when tier is insufficient',
        (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkAccess(
            context,
            requiredTier: 'pro',
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isFalse);
      expect(result.isBlocked, isTrue);
    });

    testWidgets('result contains correct currentTier', (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'basic',
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkAccess(
            context,
            requiredTier: 'free',
          );
          return const SizedBox();
        }),
      ));
      expect(result.currentTier.id, 'basic');
      expect(result.currentTier.level, 1);
    });

    testWidgets('result contains correct requiredTier', (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkAccess(
            context,
            requiredTier: 'premium',
          );
          return const SizedBox();
        }),
      ));
      expect(result.requiredTier?.id, 'premium');
      expect(result.requiredTier?.level, 3);
    });

    testWidgets(
        'grants access during active trial when allowDuringTrial is true',
        (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkAccess(
            context,
            requiredTier: 'pro',
            allowDuringTrial: true,
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isTrue);
      expect(result.isTrialing, isTrue);
    });

    testWidgets('blocks during trial when allowDuringTrial is false',
        (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkAccess(
            context,
            requiredTier: 'pro',
            allowDuringTrial: false,
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isFalse);
    });

    testWidgets('blocks when trial is expired', (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkAccess(
            context,
            requiredTier: 'pro',
            allowDuringTrial: true,
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isFalse);
    });

    testWidgets('throws when no provider in tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            // Call inside build to trigger the throw
            SubscriptionRouteGuard.checkAccess(
              context,
              requiredTier: 'pro',
            );
            return const SizedBox();
          }),
        ),
      );

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(
        (error as FlutterError).toString(),
        contains('SubscriptionGuardProvider'),
      );
    });
  });

  // =========================================================================
  // Group 3 — SubscriptionRouteGuard.checkFeatureAccess
  // =========================================================================
  group('SubscriptionRouteGuard.checkFeatureAccess', () {
    testWidgets('returns hasAccess true for accessible feature',
        (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkFeatureAccess(
            context,
            featureId: 'advanced_stats',
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isTrue);
    });

    testWidgets('returns hasAccess true for lower tier feature',
        (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkFeatureAccess(
            context,
            featureId: 'basic_stats',
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isTrue);
    });

    testWidgets('returns hasAccess false for inaccessible feature',
        (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkFeatureAccess(
            context,
            featureId: 'team_management',
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isFalse);
      expect(result.requiredTier?.id, 'premium');
    });

    testWidgets('throws for non-existent feature id', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          SubscriptionRouteGuard.checkFeatureAccess(
            context,
            featureId: 'nonexistent',
          );
          return const SizedBox();
        }),
      ));

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect(
        (error as StateError).message,
        contains('nonexistent'),
      );
    });

    testWidgets('respects trial state', (tester) async {
      late RouteAccessResult result;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
        child: Builder(builder: (context) {
          result = SubscriptionRouteGuard.checkFeatureAccess(
            context,
            featureId: 'advanced_stats',
            allowDuringTrial: true,
          );
          return const SizedBox();
        }),
      ));
      expect(result.hasAccess, isTrue);
      expect(result.isTrialing, isTrue);
    });
  });

  // =========================================================================
  // Group 4 — subscriptionRedirect (GoRouter compatible)
  // =========================================================================
  group('subscriptionRedirect — GoRouter compatible', () {
    testWidgets('returns null (no redirect) when access granted',
        (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, isNull);
    });

    testWidgets('returns redirect path when access denied', (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, '/upgrade');
    });

    testWidgets('returns null when higher tier accesses lower requirement',
        (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'basic',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, isNull);
    });

    testWidgets('appends query params to redirect path when provided',
        (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
        redirectQueryParams: {'from': 'analytics', 'required': 'pro'},
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, isNotNull);
      final uri = Uri.parse(redirectResult!);
      expect(uri.path, '/upgrade');
      expect(uri.queryParameters['from'], 'analytics');
      expect(uri.queryParameters['required'], 'pro');
    });

    testWidgets('customRedirect overrides default redirect path',
        (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
        customRedirect: (context, required, current) =>
            '/custom-page?tier=${required.id}',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, '/custom-page?tier=pro');
    });

    testWidgets('customRedirect receives correct tier objects', (tester) async {
      Tier? capturedRequired;
      Tier? capturedCurrent;

      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
        customRedirect: (context, required, current) {
          capturedRequired = required;
          capturedCurrent = current;
          return '/custom';
        },
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(capturedRequired?.id, 'pro');
      expect(capturedRequired?.level, 2);
      expect(capturedCurrent?.id, 'free');
      expect(capturedCurrent?.level, 0);
    });

    testWidgets('allows access during active trial when allowDuringTrial true',
        (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
        allowDuringTrial: true,
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, isNull);
    });

    testWidgets('redirects during trial when allowDuringTrial false',
        (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
        allowDuringTrial: false,
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, '/upgrade');
    });

    testWidgets('calls reportBlocked on scope when redirecting',
        (tester) async {
      var reportedBlocked = false;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onFeatureBlocked: (featureId, requiredTier, currentTier) {
          reportedBlocked = true;
        },
        child: Builder(builder: (context) {
          redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(reportedBlocked, isTrue);
    });

    testWidgets('does not call reportBlocked when access granted',
        (tester) async {
      var reportedBlocked = false;
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        onFeatureBlocked: (featureId, requiredTier, currentTier) {
          reportedBlocked = true;
        },
        child: Builder(builder: (context) {
          redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(reportedBlocked, isFalse);
    });
  });

  // =========================================================================
  // Group 5 — subscriptionFeatureRedirect (GoRouter compatible)
  // =========================================================================
  group('subscriptionFeatureRedirect — GoRouter compatible', () {
    testWidgets('returns null when user has feature access', (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionFeatureRedirect(
        featureId: 'advanced_stats',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, isNull);
    });

    testWidgets('returns redirect path when user lacks feature access',
        (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionFeatureRedirect(
        featureId: 'team_management',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, '/upgrade');
    });

    testWidgets('resolves feature to correct tier before checking',
        (tester) async {
      late String? redirectResult;
      final redirectFn = subscriptionFeatureRedirect(
        featureId: 'export_pdf', // requires 'pro'
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'basic', // level 1 < pro level 2
        child: Builder(builder: (context) {
          redirectResult = redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(redirectResult, '/upgrade');
    });

    testWidgets('throws for non-existent feature id', (tester) async {
      final redirectFn = subscriptionFeatureRedirect(
        featureId: 'nonexistent',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect(
        (error as StateError).message,
        contains('nonexistent'),
      );
    });

    testWidgets('respects allowDuringTrial', (tester) async {
      late String? resultAllowed;
      late String? resultBlocked;

      final fnAllowed = subscriptionFeatureRedirect(
        featureId: 'advanced_stats',
        redirectPath: '/upgrade',
        allowDuringTrial: true,
      );

      final fnBlocked = subscriptionFeatureRedirect(
        featureId: 'advanced_stats',
        redirectPath: '/upgrade',
        allowDuringTrial: false,
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
        child: Builder(builder: (context) {
          resultAllowed = fnAllowed(context, null);
          resultBlocked = fnBlocked(context, null);
          return const SizedBox();
        }),
      ));

      expect(resultAllowed, isNull);
      expect(resultBlocked, '/upgrade');
    });
  });

  // =========================================================================
  // Group 6 — SubscriptionRouteGuard.pushGuarded
  // =========================================================================
  group('SubscriptionRouteGuard.pushGuarded', () {
    testWidgets('pushes route when access granted', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('DESTINATION'),
                  ),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('DESTINATION'), findsOneWidget);
    });

    testWidgets('does NOT push route when access denied', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('DESTINATION'),
                  ),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('DESTINATION'), findsNothing);
    });

    testWidgets('calls onBlocked callback when blocked', (tester) async {
      Tier? blockedRequired;
      Tier? blockedCurrent;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<void>(
                  builder: (_) => const SizedBox(),
                ),
                onBlocked: (required, current) {
                  blockedRequired = required;
                  blockedCurrent = current;
                },
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(blockedRequired?.id, 'pro');
      expect(blockedCurrent?.id, 'free');
    });

    testWidgets('does NOT call onBlocked when access granted', (tester) async {
      var blocked = false;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('DESTINATION'),
                  ),
                ),
                onBlocked: (_, __) {
                  blocked = true;
                },
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(blocked, isFalse);
      expect(find.text('DESTINATION'), findsOneWidget);
    });

    testWidgets(
        'calls requestUpgrade when blocked and requestUpgradeOnBlock is true',
        (tester) async {
      Tier? upgradeTier;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onUpgradeRequested: (tier) {
          upgradeTier = tier;
        },
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<void>(
                  builder: (_) => const SizedBox(),
                ),
                requestUpgradeOnBlock: true,
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(upgradeTier?.id, 'pro');
    });

    testWidgets(
        'does NOT call requestUpgrade when requestUpgradeOnBlock is false',
        (tester) async {
      Tier? upgradeTier;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onUpgradeRequested: (tier) {
          upgradeTier = tier;
        },
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<void>(
                  builder: (_) => const SizedBox(),
                ),
                requestUpgradeOnBlock: false,
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(upgradeTier, isNull);
    });

    testWidgets('returns null when blocked', (tester) async {
      Object? pushResult = 'sentinel';

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              pushResult = await SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<String>(
                  builder: (_) => const SizedBox(),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(pushResult, isNull);
    });

    testWidgets('respects trial state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('TRIAL DESTINATION'),
                  ),
                ),
                allowDuringTrial: true,
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('TRIAL DESTINATION'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 7 — SubscriptionRouteGuard.pushNamedGuarded
  // =========================================================================
  group('SubscriptionRouteGuard.pushNamedGuarded', () {
    testWidgets('pushes named route when access granted', (tester) async {
      await tester.pumpWidget(buildRoutedApp(
        currentTier: 'pro',
        homeChild: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushNamedGuarded(
                context,
                requiredTier: 'pro',
                routeName: '/destination',
              );
            },
            child: const Text('Navigate'),
          );
        }),
        routes: {
          '/destination': (_) => const Scaffold(body: Text('ARRIVED')),
        },
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('ARRIVED'), findsOneWidget);
    });

    testWidgets('does NOT push named route when blocked', (tester) async {
      await tester.pumpWidget(buildRoutedApp(
        currentTier: 'free',
        homeChild: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushNamedGuarded(
                context,
                requiredTier: 'pro',
                routeName: '/destination',
              );
            },
            child: const Text('Navigate'),
          );
        }),
        routes: {
          '/destination': (_) => const Scaffold(body: Text('ARRIVED')),
        },
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('ARRIVED'), findsNothing);
    });

    testWidgets('passes arguments to named route', (tester) async {
      Object? receivedArgs;

      await tester.pumpWidget(buildRoutedApp(
        currentTier: 'pro',
        homeChild: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushNamedGuarded(
                context,
                requiredTier: 'pro',
                routeName: '/destination',
                arguments: {'key': 'value'},
              );
            },
            child: const Text('Navigate'),
          );
        }),
        routes: {
          '/destination': (context) {
            receivedArgs = ModalRoute.of(context)?.settings.arguments;
            return const Scaffold(body: Text('ARRIVED'));
          },
        },
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(receivedArgs, isA<Map>());
      expect((receivedArgs as Map)['key'], 'value');
    });

    testWidgets('calls onBlocked with correct tiers when blocked',
        (tester) async {
      Tier? blockedRequired;
      Tier? blockedCurrent;

      await tester.pumpWidget(buildRoutedApp(
        currentTier: 'free',
        homeChild: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushNamedGuarded(
                context,
                requiredTier: 'pro',
                routeName: '/destination',
                onBlocked: (required, current) {
                  blockedRequired = required;
                  blockedCurrent = current;
                },
              );
            },
            child: const Text('Navigate'),
          );
        }),
        routes: {
          '/destination': (_) => const Scaffold(body: Text('ARRIVED')),
        },
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(blockedRequired?.id, 'pro');
      expect(blockedCurrent?.id, 'free');
      expect(find.text('ARRIVED'), findsNothing);
    });
  });

  // =========================================================================
  // Group 8 — SubscriptionRouteGuard.pushFeatureGuarded
  // =========================================================================
  group('SubscriptionRouteGuard.pushFeatureGuarded', () {
    testWidgets('pushes route when user has feature access', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushFeatureGuarded(
                context,
                featureId: 'advanced_stats',
                route: MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('FEATURE PAGE'),
                  ),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('FEATURE PAGE'), findsOneWidget);
    });

    testWidgets('blocks when user lacks feature access', (tester) async {
      Tier? blockedRequired;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushFeatureGuarded(
                context,
                featureId: 'team_management',
                route: MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('FEATURE PAGE'),
                  ),
                ),
                onBlocked: (required, current) {
                  blockedRequired = required;
                },
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('FEATURE PAGE'), findsNothing);
      expect(blockedRequired?.id, 'premium');
    });

    testWidgets('throws for non-existent feature', (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushFeatureGuarded(
                context,
                featureId: 'nonexistent',
                route: MaterialPageRoute<void>(
                  builder: (_) => const SizedBox(),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect(
        (error as StateError).message,
        contains('nonexistent'),
      );
    });
  });

  // =========================================================================
  // Group 9 — SubscriptionPageRoute
  // =========================================================================
  group('SubscriptionPageRoute', () {
    testWidgets('shows actual page when access granted', (tester) async {
      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const Scaffold(body: Text('PRO PAGE')),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('PRO PAGE'), findsOneWidget);
    });

    testWidgets('shows blocked page when access denied', (tester) async {
      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const Scaffold(body: Text('PRO PAGE')),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('PRO PAGE'), findsNothing);
      expect(find.byType(DefaultLockedWidget), findsOneWidget);
    });

    testWidgets('uses custom blockedBuilder when provided', (tester) async {
      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const Scaffold(body: Text('PRO PAGE')),
                  blockedBuilder: (context, required, current) =>
                      Scaffold(body: Text('BLOCKED: ${required.id}')),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('BLOCKED: pro'), findsOneWidget);
      expect(find.text('PRO PAGE'), findsNothing);
    });

    testWidgets('uses DefaultLockedWidget when no blockedBuilder',
        (tester) async {
      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const Scaffold(body: Text('PRO PAGE')),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.byType(DefaultLockedWidget), findsOneWidget);
    });

    testWidgets('calls onBlocked when page is blocked', (tester) async {
      Tier? blockedRequired;
      Tier? blockedCurrent;

      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const SizedBox(),
                  onBlocked: (required, current) {
                    blockedRequired = required;
                    blockedCurrent = current;
                  },
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(blockedRequired?.id, 'pro');
      expect(blockedCurrent?.id, 'free');
    });

    testWidgets('calls reportBlocked on scope when blocked', (tester) async {
      var reported = false;

      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'free',
        onFeatureBlocked: (featureId, requiredTier, currentTier) {
          reported = true;
        },
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const SizedBox(),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(reported, isTrue);
    });

    testWidgets('respects allowDuringTrial', (tester) async {
      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'free',
        trialInfo: TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 7)),
        ),
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const Scaffold(body: Text('PRO PAGE')),
                  allowDuringTrial: true,
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('PRO PAGE'), findsOneWidget);
    });

    testWidgets('page route works with Navigator.push', (tester) async {
      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'premium',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'basic',
                  builder: (_) =>
                      const Scaffold(body: Text('BASIC PAGE PUSHED')),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('BASIC PAGE PUSHED'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 10 — Navigation guard edge cases
  // =========================================================================
  group('Navigation guard edge cases', () {
    testWidgets('redirect function can be reused for multiple routes',
        (tester) async {
      final redirectFn = subscriptionRedirect(
        requiredTier: 'pro',
        redirectPath: '/upgrade',
      );

      // First use — blocked
      late String? result1;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        child: Builder(builder: (context) {
          result1 = redirectFn(context, null);
          return const SizedBox();
        }),
      ));
      expect(result1, '/upgrade');

      // Second use — allowed
      late String? result2;
      await tester.pumpWidget(buildTestApp(
        currentTier: 'premium',
        child: Builder(builder: (context) {
          result2 = redirectFn(context, null);
          return const SizedBox();
        }),
      ));
      expect(result2, isNull);
    });

    testWidgets('pushGuarded returns route result when access granted',
        (tester) async {
      Object? pushResult;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              pushResult = await SubscriptionRouteGuard.pushGuarded<String>(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<String>(
                  builder: (ctx) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop('hello'),
                      child: const Text('POP'),
                    ),
                  ),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      // Now pop with result
      await tester.tap(find.text('POP'));
      await tester.pumpAndSettle();

      expect(pushResult, 'hello');
    });

    testWidgets('multiple sequential pushGuarded calls work correctly',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        currentTier: 'basic',
        child: Builder(builder: (context) {
          return Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  SubscriptionRouteGuard.pushGuarded(
                    context,
                    requiredTier: 'basic',
                    route: MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('BASIC DEST')),
                    ),
                  );
                },
                child: const Text('Go Basic'),
              ),
              ElevatedButton(
                onPressed: () {
                  SubscriptionRouteGuard.pushGuarded(
                    context,
                    requiredTier: 'premium',
                    route: MaterialPageRoute<void>(
                      builder: (_) =>
                          const Scaffold(body: Text('PREMIUM DEST')),
                    ),
                  );
                },
                child: const Text('Go Premium'),
              ),
            ],
          );
        }),
      ));

      // First push — basic granted
      await tester.tap(find.text('Go Basic'));
      await tester.pumpAndSettle();
      expect(find.text('BASIC DEST'), findsOneWidget);

      // Pop back
      final NavigatorState nav = tester.state(find.byType(Navigator).first);
      nav.pop();
      await tester.pumpAndSettle();

      // Second push — premium blocked
      await tester.tap(find.text('Go Premium'));
      await tester.pumpAndSettle();
      expect(find.text('PREMIUM DEST'), findsNothing);
    });

    testWidgets('checkAccess works in deeply nested widget tree',
        (tester) async {
      late RouteAccessResult result;

      Widget nested(int depth, Widget child) {
        if (depth == 0) return child;
        return Container(child: nested(depth - 1, child));
      }

      await tester.pumpWidget(buildTestApp(
        currentTier: 'pro',
        child: nested(
          5,
          Builder(builder: (context) {
            result = SubscriptionRouteGuard.checkAccess(
              context,
              requiredTier: 'basic',
            );
            return const SizedBox();
          }),
        ),
      ));

      expect(result.hasAccess, isTrue);
      expect(result.currentTier.id, 'pro');
    });

    testWidgets(
        'subscriptionFeatureRedirect calls reportBlocked with featureId',
        (tester) async {
      String? reportedFeatureId;

      final redirectFn = subscriptionFeatureRedirect(
        featureId: 'team_management',
        redirectPath: '/upgrade',
      );

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onFeatureBlocked: (featureId, requiredTier, currentTier) {
          reportedFeatureId = featureId;
        },
        child: Builder(builder: (context) {
          redirectFn(context, null);
          return const SizedBox();
        }),
      ));

      expect(reportedFeatureId, 'team_management');
    });

    testWidgets('pushGuarded calls reportBlocked on scope when blocked',
        (tester) async {
      var reported = false;

      await tester.pumpWidget(buildTestApp(
        currentTier: 'free',
        onFeatureBlocked: (featureId, requiredTier, currentTier) {
          reported = true;
        },
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SubscriptionRouteGuard.pushGuarded(
                context,
                requiredTier: 'pro',
                route: MaterialPageRoute<void>(
                  builder: (_) => const SizedBox(),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(reported, isTrue);
    });

    testWidgets('SubscriptionPageRoute with fullscreenDialog', (tester) async {
      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'pro',
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const Scaffold(body: Text('FULLSCREEN')),
                  fullscreenDialog: true,
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('FULLSCREEN'), findsOneWidget);
    });

    testWidgets('SubscriptionPageRoute blocked shows upgrade button',
        (tester) async {
      Tier? upgradeTier;

      await tester.pumpWidget(buildPageRouteApp(
        currentTier: 'free',
        onUpgradeRequested: (tier) {
          upgradeTier = tier;
        },
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                SubscriptionPageRoute<void>(
                  requiredTier: 'pro',
                  builder: (_) => const SizedBox(),
                ),
              );
            },
            child: const Text('Navigate'),
          );
        }),
      ));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      // DefaultLockedWidget should have an upgrade button
      final upgradeButton = find.text('Upgrade to Pro');
      expect(upgradeButton, findsOneWidget);

      // Tap the upgrade button
      await tester.tap(upgradeButton);
      await tester.pumpAndSettle();

      expect(upgradeTier?.id, 'pro');
    });
  });
}
