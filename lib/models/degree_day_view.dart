import '../constants/degree_day_constants.dart';
import 'degree_day_record.dart';

/// A table row: one day's record plus its derived cumulative total and,
/// if this is the day a management threshold was first crossed, that threshold.
class DegreeDayRow {
  const DegreeDayRow({
    required this.record,
    required this.dailyGdd,
    required this.cumulativeGdd,
    this.crossedThreshold,
    this.missingDaysBefore = 0,
  });

  final DegreeDayRecord record;

  /// Degree days for this day alone, computed with the active model.
  final double dailyGdd;

  /// Running total of daily GDD from biofix through this day (inclusive).
  final double cumulativeGdd;

  /// Non-null when this is the first day cumulative GDD reached a threshold.
  final DegreeDayThreshold? crossedThreshold;

  /// Calendar days strictly between this record and the previous one in the
  /// series (0 for the first row or for consecutive days). The weather source
  /// silently omits days it has no reading for, so a gap here means those days
  /// contributed no degree days to the cumulative total, understating it by
  /// whatever they would have added.
  final int missingDaysBefore;

  DateTime get date => record.date;
  double get tMax => record.tMax;
  double get tMin => record.tMin;
  bool get isThresholdRow => crossedThreshold != null;
  bool get hasGapBefore => missingDaysBefore > 0;
}

/// Aggregate status shown in the header above the table.
class DegreeDaySummary {
  const DegreeDaySummary({
    required this.currentCumulative,
    this.nextThreshold,
    this.missingDays = 0,
  });

  /// The latest cumulative degree-day total (0 if no data yet).
  final double currentCumulative;

  /// The next threshold not yet reached, or null if all have been crossed.
  final DegreeDayThreshold? nextThreshold;

  /// Total calendar days within the displayed range that the weather source
  /// had no reading for (sum of every row's [DegreeDayRow.missingDaysBefore]).
  /// Each one means [currentCumulative] is missing that day's contribution.
  final int missingDays;

  /// Degree days remaining until [nextThreshold], or null if none remain.
  double? get degreeDaysRemaining => nextThreshold == null
      ? null
      : (nextThreshold!.degreeDays - currentCumulative).clamp(
          0,
          double.infinity,
        );
}
