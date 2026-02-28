/// Defines the [Tier] model used throughout the subscription_guard package.
///
/// A [Tier] represents a single subscription tier with a unique identifier,
/// a numeric level for hierarchy comparison, and a human-readable label.
library;

/// Represents a single subscription tier.
///
/// Each tier has a unique [id], a numeric [level] that determines its position
/// in the subscription hierarchy (higher means more access), and a [label]
/// for display purposes.
///
/// Two tiers are considered equal if they share the same [id], regardless of
/// their [level] or [label] values.
///
/// Tiers implement [Comparable] based on [level], making them sortable from
/// lowest to highest access.
///
/// Example:
/// ```dart
/// final proTier = Tier(id: 'pro', level: 2, label: 'Pro');
/// ```
class Tier implements Comparable<Tier> {
  /// Creates a new [Tier] with the given [id], [level], and [label].
  ///
  /// All parameters are required:
  /// - [id]: A unique string identifier for this tier (e.g., `'pro'`).
  /// - [level]: An integer representing the hierarchy level. Higher values
  ///   grant more access.
  /// - [label]: A human-readable display name for this tier (e.g., `'Pro'`).
  const Tier({
    required this.id,
    required this.level,
    required this.label,
  });

  /// The unique identifier for this tier.
  ///
  /// Used for equality checks and to map features to tiers.
  final String id;

  /// The numeric hierarchy level of this tier.
  ///
  /// Higher values indicate more access. Used for tier comparison
  /// and sorting.
  final int level;

  /// The human-readable display name for this tier.
  ///
  /// Intended for use in UI elements such as labels, badges, or dialogs.
  final String label;

  /// Returns `true` if this tier's [level] is strictly greater than [other]'s.
  ///
  /// Example:
  /// ```dart
  /// final pro = Tier(id: 'pro', level: 2, label: 'Pro');
  /// final free = Tier(id: 'free', level: 0, label: 'Free');
  /// pro.isHigherThan(free); // true
  /// ```
  bool isHigherThan(Tier other) => level > other.level;

  /// Returns `true` if this tier's [level] is strictly less than [other]'s.
  ///
  /// Example:
  /// ```dart
  /// final free = Tier(id: 'free', level: 0, label: 'Free');
  /// final pro = Tier(id: 'pro', level: 2, label: 'Pro');
  /// free.isLowerThan(pro); // true
  /// ```
  bool isLowerThan(Tier other) => level < other.level;

  /// Returns `true` if this tier's [level] is greater than or equal to
  /// [other]'s.
  ///
  /// Useful for checking whether a user's current tier meets or exceeds
  /// a required tier.
  ///
  /// Example:
  /// ```dart
  /// final pro = Tier(id: 'pro', level: 2, label: 'Pro');
  /// final basic = Tier(id: 'basic', level: 1, label: 'Basic');
  /// pro.isAtLeast(basic); // true
  /// pro.isAtLeast(pro);   // true
  /// ```
  bool isAtLeast(Tier other) => level >= other.level;

  /// Creates a copy of this [Tier] with the given fields replaced.
  ///
  /// Any parameter that is not provided will retain its current value.
  ///
  /// Example:
  /// ```dart
  /// final pro = Tier(id: 'pro', level: 2, label: 'Pro');
  /// final proPlusLabel = pro.copyWith(label: 'Pro+');
  /// ```
  Tier copyWith({
    String? id,
    int? level,
    String? label,
  }) {
    return Tier(
      id: id ?? this.id,
      level: level ?? this.level,
      label: label ?? this.label,
    );
  }

  /// Compares this tier to [other] based on [level].
  ///
  /// Returns a negative value if this tier's level is less than [other]'s,
  /// zero if they are equal, and a positive value if this tier's level is
  /// greater.
  @override
  int compareTo(Tier other) => level.compareTo(other.level);

  /// Two tiers are equal if they share the same [id].
  ///
  /// The [level] and [label] are not considered for equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Tier && other.id == id);

  /// Hash code based solely on [id].
  @override
  int get hashCode => id.hashCode;

  /// Returns a string representation of this tier for debugging.
  ///
  /// Format: `Tier(id: pro, level: 2, label: Pro)`
  @override
  String toString() => 'Tier(id: $id, level: $level, label: $label)';
}
