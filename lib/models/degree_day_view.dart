import '../constants/degree_day_constants.dart';
import 'degree_day_record.dart';
import 'station.dart';

/// A table row: one day's record plus its derived cumulative total and,
/// if this is the day a management threshold was first crossed, that threshold.
class DegreeDayRow {
  const DegreeDayRow({
    required this.record,
    required this.dailyGdd,
    required this.cumulativeGdd,
    this.crossedThreshold,
  });

  final DegreeDayRecord record;

  /// Degree days for this day alone, computed with the active model.
  final double dailyGdd;

  /// Running total of daily GDD from biofix through this day (inclusive).
  final double cumulativeGdd;

  /// Non-null when this is the first day cumulative GDD reached a threshold.
  final DegreeDayThreshold? crossedThreshold;

  DateTime get date => record.date;
  double get tMax => record.tMax;
  double get tMin => record.tMin;
  bool get isThresholdRow => crossedThreshold != null;
}

/// Aggregate status shown in the header above the table.
class DegreeDaySummary {
  const DegreeDaySummary({required this.currentCumulative, this.nextThreshold});

  /// The latest cumulative degree-day total (0 if no data yet).
  final double currentCumulative;

  /// The next threshold not yet reached, or null if all have been crossed.
  final DegreeDayThreshold? nextThreshold;

  /// Degree days remaining until [nextThreshold], or null if none remain.
  double? get degreeDaysRemaining => nextThreshold == null
      ? null
      : (nextThreshold!.degreeDays - currentCumulative).clamp(
          0,
          double.infinity,
        );
}

/// One station's standing for the comparison page: its [summary] plus the date
/// of its most recent observation (null when the station has no cached data).
///
/// Every station in an orchard shares the same biofix, model, and thresholds, so
/// any difference between two [StationComparison]s reflects only their weather.
class StationComparison {
  const StationComparison({
    required this.station,
    required this.summary,
    this.lastDate,
  });

  final Station station;
  final DegreeDaySummary summary;

  /// Date of the newest observation feeding [summary], or null if none.
  final DateTime? lastDate;

  /// Cumulative degree days to date — the value rows are ranked by.
  double get currentCumulative => summary.currentCumulative;
}
