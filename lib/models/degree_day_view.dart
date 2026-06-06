import '../constants/degree_day_constants.dart';
import 'degree_day_record.dart';

/// A table row: one day's record plus its derived cumulative total and,
/// if this is the day a management threshold was first crossed, that threshold.
class DegreeDayRow {
  const DegreeDayRow({
    required this.record,
    required this.cumulativeGdd,
    this.crossedThreshold,
  });

  final DegreeDayRecord record;

  /// Running total of daily GDD from biofix through this day (inclusive).
  final double cumulativeGdd;

  /// Non-null when this is the first day cumulative GDD reached a threshold.
  final DegreeDayThreshold? crossedThreshold;

  DateTime get date => record.date;
  double get tMax => record.tMax;
  double get tMin => record.tMin;
  double get dailyGdd => record.dailyGdd;
  bool get isThresholdRow => crossedThreshold != null;
}

/// Aggregate status shown in the header above the table.
class DegreeDaySummary {
  const DegreeDaySummary({
    required this.currentCumulative,
    this.nextThreshold,
  });

  /// The latest cumulative degree-day total (0 if no data yet).
  final double currentCumulative;

  /// The next threshold not yet reached, or null if all have been crossed.
  final DegreeDayThreshold? nextThreshold;

  /// Degree days remaining until [nextThreshold], or null if none remain.
  double? get degreeDaysRemaining => nextThreshold == null
      ? null
      : (nextThreshold!.degreeDays - currentCumulative).clamp(0, double.infinity);
}
