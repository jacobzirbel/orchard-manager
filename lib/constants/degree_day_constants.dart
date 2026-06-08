/// Default parameters + threshold definitions for the codling moth degree-day
/// model (Cydia pomonella). The base temperature and cutoffs are user-
/// configurable at runtime (the runtime values live in the degree-day model
/// settings); the constants here are only the out-of-the-box defaults.
library;

/// Default base temperature in °F (the lower developmental threshold).
const double kBaseTempF = 50.0;

/// Default upper cutoff in °F: the daily high is capped here before averaging,
/// the codling moth standard.
const double kUpperCutoffF = 88.0;

/// A management threshold expressed in cumulative degree days from biofix.
class DegreeDayThreshold {
  const DegreeDayThreshold({required this.degreeDays, required this.label});

  /// Cumulative degree days (from biofix) at which this event occurs.
  final double degreeDays;

  /// The recommended action / biological event at this threshold.
  final String label;

  Map<String, Object?> toJson() => {'degreeDays': degreeDays, 'label': label};

  factory DegreeDayThreshold.fromJson(Map<String, dynamic> json) =>
      DegreeDayThreshold(
        degreeDays: (json['degreeDays'] as num).toDouble(),
        label: json['label'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is DegreeDayThreshold &&
      other.degreeDays == degreeDays &&
      other.label == label;

  @override
  int get hashCode => Object.hash(degreeDays, label);
}

/// Default codling moth management thresholds, in ascending order.
///
/// These are the out-of-the-box defaults; the user can edit, add, or remove
/// them in the degree-day model settings. They drive both the highlighted rows
/// in the table and the "next threshold" summary in the header.
const List<DegreeDayThreshold> kThresholds = [
  DegreeDayThreshold(degreeDays: 150, label: '1st flight — ovicide (if used)'),
  DegreeDayThreshold(
    degreeDays: 250,
    label: '1st flight egg hatch — first cover spray',
  ),
  DegreeDayThreshold(degreeDays: 1100, label: '2nd flight — adults emerge'),
  DegreeDayThreshold(degreeDays: 1350, label: '2nd flight — larvae present'),
  DegreeDayThreshold(degreeDays: 1400, label: '2nd flight — larvicide spray'),
  DegreeDayThreshold(degreeDays: 1900, label: '3rd flight begins'),
];
