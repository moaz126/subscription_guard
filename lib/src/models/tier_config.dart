/// Defines the [SubscriptionConfig] model, the central configuration that
/// holds all subscription tiers and maps features to their required tiers.
library;

import 'tier.dart';

/// Central configuration that defines all subscription tiers and
/// feature-to-tier mappings.
///
/// The [tiers] list must contain at least one tier, must not have duplicate
/// tier ids or duplicate tier levels, and is stored sorted by level in
/// ascending order.
///
/// The [features] map associates feature identifiers with the tier id
/// required to access them. All tier ids referenced in [features] must
/// exist in the [tiers] list.
///
/// Example:
/// ```dart
/// final config = SubscriptionConfig(
///   tiers: [
///     Tier(id: 'free', level: 0, label: 'Free'),
///     Tier(id: 'pro', level: 1, label: 'Pro'),
///     Tier(id: 'premium', level: 2, label: 'Premium'),
///   ],
///   features: {
///     'basic_stats': 'free',
///     'advanced_stats': 'pro',
///     'export_pdf': 'pro',
///     'team_management': 'premium',
///   },
/// );
/// ```
class SubscriptionConfig {
  /// Creates a new [SubscriptionConfig] with the given [tiers] and optional
  /// [features] mapping.
  ///
  /// The [tiers] list is sorted by level ascending internally. In debug mode,
  /// the following assertions are checked:
  /// - [tiers] must not be empty.
  /// - No duplicate tier ids.
  /// - No duplicate tier levels.
  /// - All tier ids referenced in [features] must exist in [tiers].
  SubscriptionConfig({
    required List<Tier> tiers,
    this.features = const {},
  })  : assert(tiers.isNotEmpty, 'Tiers list must not be empty.'),
        assert(
          tiers.map((t) => t.id).toSet().length == tiers.length,
          'Duplicate tier ids detected.',
        ),
        assert(
          tiers.map((t) => t.level).toSet().length == tiers.length,
          'Duplicate tier levels detected.',
        ),
        assert(
          features.values.every(
            (tierId) => tiers.any((t) => t.id == tierId),
          ),
          'All feature tier ids must exist in the tiers list.',
        ),
        tiers = List<Tier>.unmodifiable(
          List<Tier>.of(tiers)..sort((a, b) => a.compareTo(b)),
        );

  /// All available subscription tiers, sorted by [Tier.level] ascending.
  ///
  /// This list is guaranteed to contain at least one tier and to have no
  /// duplicate ids or levels.
  final List<Tier> tiers;

  /// Maps feature identifiers to the tier id required to access them.
  ///
  /// An empty map means no feature-to-tier mappings have been configured.
  /// All tier id values in this map are guaranteed to exist in [tiers]
  /// (validated via assertions in debug mode).
  final Map<String, String> features;

  /// Returns the [Tier] with the given [id].
  ///
  /// Throws a [StateError] if no tier with the given [id] exists.
  ///
  /// Example:
  /// ```dart
  /// final pro = config.getTierById('pro');
  /// ```
  Tier getTierById(String id) {
    return tiers.firstWhere(
      (tier) => tier.id == id,
      orElse: () => throw StateError('No tier found with id: $id'),
    );
  }

  /// Returns the [Tier] with the given [id], or `null` if not found.
  ///
  /// Example:
  /// ```dart
  /// final tier = config.findTierById('enterprise'); // null if not defined
  /// ```
  Tier? findTierById(String id) {
    for (final tier in tiers) {
      if (tier.id == id) return tier;
    }
    return null;
  }

  /// The tier with the lowest [Tier.level].
  ///
  /// Since tiers are sorted ascending by level, this is the first element.
  Tier get lowestTier => tiers.first;

  /// The tier with the highest [Tier.level].
  ///
  /// Since tiers are sorted ascending by level, this is the last element.
  Tier get highestTier => tiers.last;

  /// Returns the tier id required to access the feature with the given
  /// [featureId], or `null` if the feature is not mapped.
  ///
  /// Example:
  /// ```dart
  /// final tierId = config.getRequiredTierForFeature('export_pdf'); // 'pro'
  /// ```
  String? getRequiredTierForFeature(String featureId) {
    return features[featureId];
  }

  /// Returns `true` if a feature with the given [featureId] exists in
  /// the [features] map.
  bool hasFeature(String featureId) {
    return features.containsKey(featureId);
  }

  /// Returns all feature ids that require exactly the tier with the given
  /// [tierId].
  ///
  /// Only includes features whose required tier id matches [tierId] exactly,
  /// not features accessible at that tier level through hierarchy.
  ///
  /// Example:
  /// ```dart
  /// config.getFeaturesForTier('pro'); // ['advanced_stats', 'export_pdf']
  /// ```
  List<String> getFeaturesForTier(String tierId) {
    return features.entries
        .where((entry) => entry.value == tierId)
        .map((entry) => entry.key)
        .toList();
  }

  /// Returns all feature ids accessible at the tier level of the given
  /// [tierId].
  ///
  /// This includes features assigned to the given tier **and** all features
  /// assigned to lower tiers (since a higher tier has access to everything
  /// a lower tier can access).
  ///
  /// Throws a [StateError] if [tierId] does not exist in [tiers].
  ///
  /// Example:
  /// ```dart
  /// // If 'pro' is level 1 and 'free' is level 0:
  /// config.getAccessibleFeatures('pro');
  /// // Returns features for 'free' and 'pro'
  /// ```
  List<String> getAccessibleFeatures(String tierId) {
    final tier = getTierById(tierId);
    return features.entries
        .where((entry) {
          final requiredTier = findTierById(entry.value);
          return requiredTier != null && tier.isAtLeast(requiredTier);
        })
        .map((entry) => entry.key)
        .toList();
  }

  /// Returns `true` if the tier identified by [currentTierId] has a level
  /// greater than or equal to the tier identified by [requiredTierId].
  ///
  /// Throws a [StateError] if either tier id does not exist in [tiers].
  ///
  /// Example:
  /// ```dart
  /// config.canAccess('pro', 'free');    // true
  /// config.canAccess('free', 'pro');    // false
  /// config.canAccess('pro', 'pro');     // true
  /// ```
  bool canAccess(String currentTierId, String requiredTierId) {
    final currentTier = getTierById(currentTierId);
    final requiredTier = getTierById(requiredTierId);
    return currentTier.isAtLeast(requiredTier);
  }
}
