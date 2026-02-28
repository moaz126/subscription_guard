/// Defines the [TrialInfo] model for representing trial and grace period
/// state within the subscription_guard package.
library;

/// Holds trial or grace period information for the current subscription.
///
/// Tracks whether the user is currently in a trial period and when that
/// trial ends. Provides computed properties for checking expiration status
/// and remaining time.
///
/// A `null` [endsAt] value indicates no end date (e.g., a lifetime trial
/// or an indefinite grace period).
///
/// Example:
/// ```dart
/// final trial = TrialInfo(
///   isTrialing: true,
///   endsAt: DateTime(2026, 3, 15),
/// );
/// print(trial.daysRemaining); // 15
/// ```
class TrialInfo {
  /// Creates a new [TrialInfo] with the given [isTrialing] flag and optional
  /// [endsAt] date.
  ///
  /// - [isTrialing]: Whether the user is currently in a trial period.
  /// - [endsAt]: When the trial ends. If `null`, the trial has no end date.
  const TrialInfo({
    required this.isTrialing,
    this.endsAt,
  });

  /// Creates a [TrialInfo] representing no active trial.
  ///
  /// Equivalent to `TrialInfo(isTrialing: false, endsAt: null)`.
  ///
  /// Example:
  /// ```dart
  /// final noTrial = TrialInfo.none();
  /// print(noTrial.isActive); // false
  /// ```
  const factory TrialInfo.none() = _NoTrialInfo;

  /// Whether the user is currently in a trial period.
  ///
  /// This flag alone does not guarantee the trial is active — use [isActive]
  /// to also account for expiration.
  final bool isTrialing;

  /// When the trial period ends, or `null` if there is no end date.
  ///
  /// A `null` value indicates an indefinite trial (e.g., lifetime access
  /// or no expiration configured).
  final DateTime? endsAt;

  /// Whether the trial has expired.
  ///
  /// Returns `true` if [endsAt] is non-null and the current time is past
  /// the end date. Returns `false` if [endsAt] is `null` (no expiration).
  bool get isExpired => endsAt != null && DateTime.now().isAfter(endsAt!);

  /// Whether the trial is currently active.
  ///
  /// A trial is active when [isTrialing] is `true` and the trial has not
  /// yet expired.
  bool get isActive => isTrialing && !isExpired;

  /// The number of full days remaining in the trial, or `null` if [endsAt]
  /// is `null`.
  ///
  /// Returns a minimum of `0` — never returns a negative value.
  ///
  /// Example:
  /// ```dart
  /// final trial = TrialInfo(
  ///   isTrialing: true,
  ///   endsAt: DateTime.now().add(Duration(days: 5)),
  /// );
  /// print(trial.daysRemaining); // 5
  /// ```
  int? get daysRemaining {
    if (endsAt == null) return null;
    final difference = endsAt!.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }

  /// The [Duration] remaining in the trial, or `null` if [endsAt] is `null`.
  ///
  /// Returns a minimum of [Duration.zero] — never returns a negative duration.
  Duration? get timeRemaining {
    if (endsAt == null) return null;
    final difference = endsAt!.difference(DateTime.now());
    return difference.isNegative ? Duration.zero : difference;
  }

  /// Creates a copy of this [TrialInfo] with the given fields replaced.
  ///
  /// Any parameter that is not provided will retain its current value.
  TrialInfo copyWith({
    bool? isTrialing,
    DateTime? endsAt,
  }) {
    return TrialInfo(
      isTrialing: isTrialing ?? this.isTrialing,
      endsAt: endsAt ?? this.endsAt,
    );
  }

  /// Two [TrialInfo] instances are equal if they share the same [isTrialing]
  /// flag and [endsAt] value.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrialInfo &&
          other.isTrialing == isTrialing &&
          other.endsAt == endsAt);

  /// Hash code based on [isTrialing] and [endsAt].
  @override
  int get hashCode => Object.hash(isTrialing, endsAt);

  /// Returns a string representation of this trial info for debugging.
  ///
  /// Format: `TrialInfo(isTrialing: true, endsAt: 2026-03-15 00:00:00.000)`
  @override
  String toString() => 'TrialInfo(isTrialing: $isTrialing, endsAt: $endsAt)';
}

/// Internal implementation for [TrialInfo.none].
class _NoTrialInfo extends TrialInfo {
  /// Creates a [TrialInfo] with no active trial.
  const _NoTrialInfo() : super(isTrialing: false, endsAt: null);
}
