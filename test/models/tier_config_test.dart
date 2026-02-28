// Tests for all model classes: Tier, GuardBehavior, TrialInfo,
// and SubscriptionConfig.

import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_guard/subscription_guard.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Tier
  // ---------------------------------------------------------------------------
  group('Tier', () {
    group('constructor', () {
      test('stores id, level, and label', () {
        const tier = Tier(id: 'pro', level: 2, label: 'Pro');
        expect(tier.id, 'pro');
        expect(tier.level, 2);
        expect(tier.label, 'Pro');
      });

      test('can be const', () {
        const tier = Tier(id: 'free', level: 0, label: 'Free');
        expect(tier, isA<Tier>());
      });
    });

    group('comparison helpers', () {
      const free = Tier(id: 'free', level: 0, label: 'Free');
      const basic = Tier(id: 'basic', level: 1, label: 'Basic');
      const pro = Tier(id: 'pro', level: 2, label: 'Pro');

      test('isHigherThan returns true when level is strictly greater', () {
        expect(pro.isHigherThan(free), isTrue);
        expect(pro.isHigherThan(basic), isTrue);
      });

      test('isHigherThan returns false for equal or lower level', () {
        expect(free.isHigherThan(pro), isFalse);
        expect(pro.isHigherThan(pro), isFalse);
      });

      test('isLowerThan returns true when level is strictly less', () {
        expect(free.isLowerThan(pro), isTrue);
        expect(basic.isLowerThan(pro), isTrue);
      });

      test('isLowerThan returns false for equal or higher level', () {
        expect(pro.isLowerThan(free), isFalse);
        expect(pro.isLowerThan(pro), isFalse);
      });

      test('isAtLeast returns true when level >= other', () {
        expect(pro.isAtLeast(free), isTrue);
        expect(pro.isAtLeast(pro), isTrue);
      });

      test('isAtLeast returns false when level < other', () {
        expect(free.isAtLeast(pro), isFalse);
      });
    });

    group('Comparable', () {
      test('compareTo returns negative when level is lower', () {
        const free = Tier(id: 'free', level: 0, label: 'Free');
        const pro = Tier(id: 'pro', level: 2, label: 'Pro');
        expect(free.compareTo(pro), isNegative);
      });

      test('compareTo returns zero when levels are equal', () {
        const a = Tier(id: 'a', level: 1, label: 'A');
        const b = Tier(id: 'b', level: 1, label: 'B');
        expect(a.compareTo(b), isZero);
      });

      test('compareTo returns positive when level is higher', () {
        const pro = Tier(id: 'pro', level: 2, label: 'Pro');
        const free = Tier(id: 'free', level: 0, label: 'Free');
        expect(pro.compareTo(free), isPositive);
      });

      test('tiers sort correctly via List.sort', () {
        const premium = Tier(id: 'premium', level: 3, label: 'Premium');
        const free = Tier(id: 'free', level: 0, label: 'Free');
        const pro = Tier(id: 'pro', level: 2, label: 'Pro');
        final list = [premium, free, pro]..sort();
        expect(list.map((t) => t.id), ['free', 'pro', 'premium']);
      });
    });

    group('copyWith', () {
      const original = Tier(id: 'pro', level: 2, label: 'Pro');

      test('returns a new Tier with updated id', () {
        final copy = original.copyWith(id: 'plus');
        expect(copy.id, 'plus');
        expect(copy.level, 2);
        expect(copy.label, 'Pro');
      });

      test('returns a new Tier with updated level', () {
        final copy = original.copyWith(level: 5);
        expect(copy.level, 5);
        expect(copy.id, 'pro');
      });

      test('returns a new Tier with updated label', () {
        final copy = original.copyWith(label: 'Pro+');
        expect(copy.label, 'Pro+');
      });

      test('returns an equal-by-value copy when no args passed', () {
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.level, original.level);
        expect(copy.label, original.label);
      });
    });

    group('equality', () {
      test('tiers with the same id are equal', () {
        const a = Tier(id: 'pro', level: 2, label: 'Pro');
        const b = Tier(id: 'pro', level: 5, label: 'Different');
        expect(a, equals(b));
      });

      test('tiers with different ids are not equal', () {
        const a = Tier(id: 'pro', level: 2, label: 'Pro');
        const b = Tier(id: 'free', level: 2, label: 'Pro');
        expect(a, isNot(equals(b)));
      });

      test('hashCode is based on id only', () {
        const a = Tier(id: 'pro', level: 2, label: 'Pro');
        const b = Tier(id: 'pro', level: 9, label: 'X');
        expect(a.hashCode, b.hashCode);
      });

      test('can be used as a Set/Map key correctly', () {
        const a = Tier(id: 'pro', level: 2, label: 'Pro');
        const b = Tier(id: 'pro', level: 5, label: 'Different');
        final set = {a, b};
        expect(set.length, 1);
      });
    });

    group('toString', () {
      test('returns expected format', () {
        const tier = Tier(id: 'pro', level: 2, label: 'Pro');
        expect(tier.toString(), 'Tier(id: pro, level: 2, label: Pro)');
      });
    });
  });

  // ---------------------------------------------------------------------------
  // GuardBehavior
  // ---------------------------------------------------------------------------
  group('GuardBehavior', () {
    test('has exactly 4 values', () {
      expect(GuardBehavior.values.length, 4);
    });

    test('values are hide, disable, replace, blur', () {
      expect(
        GuardBehavior.values,
        containsAll([
          GuardBehavior.hide,
          GuardBehavior.disable,
          GuardBehavior.replace,
          GuardBehavior.blur,
        ]),
      );
    });

    test('description returns a non-empty string for each value', () {
      for (final behavior in GuardBehavior.values) {
        expect(behavior.description, isNotEmpty);
      }
    });

    test('each value has a unique description', () {
      final descriptions =
          GuardBehavior.values.map((b) => b.description).toSet();
      expect(descriptions.length, GuardBehavior.values.length);
    });
  });

  // ---------------------------------------------------------------------------
  // TrialInfo
  // ---------------------------------------------------------------------------
  group('TrialInfo', () {
    group('constructor', () {
      test('stores isTrialing and endsAt', () {
        final date = DateTime(2026, 3, 15);
        final trial = TrialInfo(isTrialing: true, endsAt: date);
        expect(trial.isTrialing, isTrue);
        expect(trial.endsAt, date);
      });

      test('endsAt defaults to null', () {
        const trial = TrialInfo(isTrialing: true);
        expect(trial.endsAt, isNull);
      });

      test('can be const', () {
        const trial = TrialInfo(isTrialing: false);
        expect(trial, isA<TrialInfo>());
      });
    });

    group('TrialInfo.none()', () {
      test('isTrialing is false', () {
        const trial = TrialInfo.none();
        expect(trial.isTrialing, isFalse);
      });

      test('endsAt is null', () {
        const trial = TrialInfo.none();
        expect(trial.endsAt, isNull);
      });

      test('is a TrialInfo instance', () {
        const trial = TrialInfo.none();
        expect(trial, isA<TrialInfo>());
      });
    });

    group('isExpired', () {
      test('returns false when endsAt is null', () {
        const trial = TrialInfo(isTrialing: true);
        expect(trial.isExpired, isFalse);
      });

      test('returns false when endsAt is in the future', () {
        final trial = TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 30)),
        );
        expect(trial.isExpired, isFalse);
      });

      test('returns true when endsAt is in the past', () {
        final trial = TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(trial.isExpired, isTrue);
      });
    });

    group('isActive', () {
      test('returns true when isTrialing is true and not expired', () {
        final trial = TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 5)),
        );
        expect(trial.isActive, isTrue);
      });

      test('returns false when isTrialing is false', () {
        final trial = TrialInfo(
          isTrialing: false,
          endsAt: DateTime.now().add(const Duration(days: 5)),
        );
        expect(trial.isActive, isFalse);
      });

      test('returns false when expired even if isTrialing is true', () {
        final trial = TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(trial.isActive, isFalse);
      });

      test('returns true when isTrialing is true and endsAt is null', () {
        const trial = TrialInfo(isTrialing: true);
        expect(trial.isActive, isTrue);
      });
    });

    group('daysRemaining', () {
      test('returns null when endsAt is null', () {
        const trial = TrialInfo(isTrialing: true);
        expect(trial.daysRemaining, isNull);
      });

      test('returns positive count for future endsAt', () {
        final trial = TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(days: 10)),
        );
        // Should be approximately 10 (could be 9 due to sub-day rounding)
        expect(trial.daysRemaining, greaterThanOrEqualTo(9));
        expect(trial.daysRemaining, lessThanOrEqualTo(10));
      });

      test('returns 0 for past endsAt (never negative)', () {
        final trial = TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(days: 5)),
        );
        expect(trial.daysRemaining, 0);
      });
    });

    group('timeRemaining', () {
      test('returns null when endsAt is null', () {
        const trial = TrialInfo(isTrialing: true);
        expect(trial.timeRemaining, isNull);
      });

      test('returns positive Duration for future endsAt', () {
        final trial = TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().add(const Duration(hours: 5)),
        );
        expect(trial.timeRemaining, isNotNull);
        expect(trial.timeRemaining!.inHours, greaterThanOrEqualTo(4));
      });

      test('returns Duration.zero for past endsAt (never negative)', () {
        final trial = TrialInfo(
          isTrialing: true,
          endsAt: DateTime.now().subtract(const Duration(hours: 2)),
        );
        expect(trial.timeRemaining, Duration.zero);
      });
    });

    group('copyWith', () {
      test('copies isTrialing', () {
        const original = TrialInfo(isTrialing: true);
        final copy = original.copyWith(isTrialing: false);
        expect(copy.isTrialing, isFalse);
      });

      test('copies endsAt', () {
        final date = DateTime(2026, 6, 1);
        const original = TrialInfo(isTrialing: true);
        final copy = original.copyWith(endsAt: date);
        expect(copy.endsAt, date);
      });

      test('retains values when no args passed', () {
        final date = DateTime(2026, 6, 1);
        final original = TrialInfo(isTrialing: true, endsAt: date);
        final copy = original.copyWith();
        expect(copy.isTrialing, isTrue);
        expect(copy.endsAt, date);
      });
    });

    group('equality', () {
      test('equal when same isTrialing and endsAt', () {
        final date = DateTime(2026, 3, 15);
        final a = TrialInfo(isTrialing: true, endsAt: date);
        final b = TrialInfo(isTrialing: true, endsAt: date);
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('not equal when isTrialing differs', () {
        final a = TrialInfo(isTrialing: true, endsAt: DateTime(2026));
        final b = TrialInfo(isTrialing: false, endsAt: DateTime(2026));
        expect(a, isNot(equals(b)));
      });

      test('not equal when endsAt differs', () {
        final a = TrialInfo(isTrialing: true, endsAt: DateTime(2026, 1));
        final b = TrialInfo(isTrialing: true, endsAt: DateTime(2026, 2));
        expect(a, isNot(equals(b)));
      });

      test('TrialInfo.none() equals TrialInfo(isTrialing: false)', () {
        const none = TrialInfo.none();
        const manual = TrialInfo(isTrialing: false);
        expect(none, equals(manual));
      });
    });

    group('toString', () {
      test('includes isTrialing and endsAt', () {
        final date = DateTime(2026, 3, 15);
        final trial = TrialInfo(isTrialing: true, endsAt: date);
        final str = trial.toString();
        expect(str, contains('isTrialing: true'));
        expect(str, contains('endsAt:'));
      });

      test('shows null endsAt', () {
        const trial = TrialInfo(isTrialing: false);
        expect(trial.toString(), contains('endsAt: null'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // SubscriptionConfig
  // ---------------------------------------------------------------------------
  group('SubscriptionConfig', () {
    // Shared test data
    const free = Tier(id: 'free', level: 0, label: 'Free');
    const basic = Tier(id: 'basic', level: 1, label: 'Basic');
    const pro = Tier(id: 'pro', level: 2, label: 'Pro');
    const premium = Tier(id: 'premium', level: 3, label: 'Premium');

    final features = <String, String>{
      'basic_stats': 'free',
      'advanced_stats': 'pro',
      'export_pdf': 'pro',
      'team_management': 'premium',
    };

    SubscriptionConfig buildConfig({
      List<Tier>? tiers,
      Map<String, String>? featureMap,
    }) {
      return SubscriptionConfig(
        tiers: tiers ?? [free, basic, pro, premium],
        features: featureMap ?? features,
      );
    }

    group('constructor and validation', () {
      test('stores tiers sorted by level ascending', () {
        final config = SubscriptionConfig(
          tiers: [premium, free, pro, basic],
          features: features,
        );
        expect(config.tiers.map((t) => t.id).toList(),
            ['free', 'basic', 'pro', 'premium']);
      });

      test('tiers list is unmodifiable', () {
        final config = buildConfig();
        expect(() => config.tiers.add(free), throwsUnsupportedError);
      });

      test('features defaults to empty map', () {
        final config = SubscriptionConfig(tiers: [free]);
        expect(config.features, isEmpty);
      });

      // Debug-mode assertion tests
      test('asserts if tiers list is empty', () {
        expect(
          () => SubscriptionConfig(tiers: []),
          throwsA(isA<AssertionError>()),
        );
      });

      test('asserts on duplicate tier ids', () {
        expect(
          () => SubscriptionConfig(
            tiers: [
              const Tier(id: 'pro', level: 1, label: 'A'),
              const Tier(id: 'pro', level: 2, label: 'B'),
            ],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('asserts on duplicate tier levels', () {
        expect(
          () => SubscriptionConfig(
            tiers: [
              const Tier(id: 'a', level: 1, label: 'A'),
              const Tier(id: 'b', level: 1, label: 'B'),
            ],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('asserts when feature references non-existent tier id', () {
        expect(
          () => SubscriptionConfig(
            tiers: [free],
            features: {'feat': 'nonexistent'},
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('getTierById', () {
      test('returns the correct tier', () {
        final config = buildConfig();
        expect(config.getTierById('pro'), pro);
      });

      test('throws StateError for unknown id', () {
        final config = buildConfig();
        expect(
          () => config.getTierById('enterprise'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('findTierById', () {
      test('returns the tier when found', () {
        final config = buildConfig();
        expect(config.findTierById('basic'), basic);
      });

      test('returns null when not found', () {
        final config = buildConfig();
        expect(config.findTierById('enterprise'), isNull);
      });
    });

    group('lowestTier / highestTier', () {
      test('lowestTier returns the tier with the smallest level', () {
        final config = buildConfig();
        expect(config.lowestTier, free);
      });

      test('highestTier returns the tier with the greatest level', () {
        final config = buildConfig();
        expect(config.highestTier, premium);
      });

      test('both return the same tier when only one tier exists', () {
        final config = SubscriptionConfig(tiers: [basic]);
        expect(config.lowestTier, basic);
        expect(config.highestTier, basic);
      });
    });

    group('getRequiredTierForFeature', () {
      test('returns the tier id for a mapped feature', () {
        final config = buildConfig();
        expect(config.getRequiredTierForFeature('export_pdf'), 'pro');
      });

      test('returns null for an unmapped feature', () {
        final config = buildConfig();
        expect(config.getRequiredTierForFeature('unknown'), isNull);
      });
    });

    group('hasFeature', () {
      test('returns true for a mapped feature', () {
        final config = buildConfig();
        expect(config.hasFeature('basic_stats'), isTrue);
      });

      test('returns false for an unmapped feature', () {
        final config = buildConfig();
        expect(config.hasFeature('nonexistent'), isFalse);
      });
    });

    group('getFeaturesForTier', () {
      test('returns features assigned exactly to the tier', () {
        final config = buildConfig();
        final proFeatures = config.getFeaturesForTier('pro');
        expect(proFeatures, unorderedEquals(['advanced_stats', 'export_pdf']));
      });

      test('returns empty list for a tier with no direct features', () {
        final config = buildConfig();
        expect(config.getFeaturesForTier('basic'), isEmpty);
      });

      test('does not include features from other tiers', () {
        final config = buildConfig();
        final freeFeatures = config.getFeaturesForTier('free');
        expect(freeFeatures, ['basic_stats']);
        expect(freeFeatures, isNot(contains('advanced_stats')));
      });
    });

    group('getAccessibleFeatures', () {
      test('premium tier can access all features', () {
        final config = buildConfig();
        final accessible = config.getAccessibleFeatures('premium');
        expect(
          accessible,
          unorderedEquals([
            'basic_stats',
            'advanced_stats',
            'export_pdf',
            'team_management',
          ]),
        );
      });

      test('pro tier can access free and pro features', () {
        final config = buildConfig();
        final accessible = config.getAccessibleFeatures('pro');
        expect(
          accessible,
          unorderedEquals([
            'basic_stats',
            'advanced_stats',
            'export_pdf',
          ]),
        );
      });

      test('free tier can only access free features', () {
        final config = buildConfig();
        final accessible = config.getAccessibleFeatures('free');
        expect(accessible, ['basic_stats']);
      });

      test('throws StateError for unknown tier id', () {
        final config = buildConfig();
        expect(
          () => config.getAccessibleFeatures('enterprise'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('canAccess', () {
      test('returns true when current tier >= required tier', () {
        final config = buildConfig();
        expect(config.canAccess('pro', 'free'), isTrue);
        expect(config.canAccess('pro', 'pro'), isTrue);
        expect(config.canAccess('premium', 'basic'), isTrue);
      });

      test('returns false when current tier < required tier', () {
        final config = buildConfig();
        expect(config.canAccess('free', 'pro'), isFalse);
        expect(config.canAccess('basic', 'premium'), isFalse);
      });

      test('throws StateError for unknown current tier id', () {
        final config = buildConfig();
        expect(
          () => config.canAccess('unknown', 'free'),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError for unknown required tier id', () {
        final config = buildConfig();
        expect(
          () => config.canAccess('free', 'unknown'),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
