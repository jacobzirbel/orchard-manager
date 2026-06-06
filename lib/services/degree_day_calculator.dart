import 'dart:math' as math;

import '../constants/degree_day_constants.dart';
import '../models/degree_day_record.dart';
import '../models/degree_day_view.dart';

/// Pure degree-day math. No I/O — kept separate so it is trivially testable.
class DegreeDayCalculator {
  const DegreeDayCalculator();

  /// Single-day GDD using the simple-average method, base 50°F.
  ///
  /// `max(0, (tMax + tMin) / 2 - 50)` — development never goes negative.
  static double dailyGdd(double tMax, double tMin) {
    final avg = (tMax + tMin) / 2.0;
    return math.max(0.0, avg - kBaseTempF);
  }

  /// Builds display rows from stored records: sorts by date, accumulates the
  /// running total, and tags the first row to reach each management threshold.
  static List<DegreeDayRow> buildRows(List<DegreeDayRecord> records) {
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));

    var cumulative = 0.0;
    var nextThresholdIndex = 0;
    final rows = <DegreeDayRow>[];

    for (final record in sorted) {
      cumulative += record.dailyGdd;

      // A single day can cross more than one threshold; attribute the highest
      // one reached on this day so the label reflects the current stage.
      DegreeDayThreshold? crossed;
      while (nextThresholdIndex < kThresholds.length &&
          cumulative >= kThresholds[nextThresholdIndex].degreeDays) {
        crossed = kThresholds[nextThresholdIndex];
        nextThresholdIndex++;
      }

      rows.add(DegreeDayRow(
        record: record,
        cumulativeGdd: cumulative,
        crossedThreshold: crossed,
      ));
    }

    return rows;
  }

  /// Derives the header summary from the (date-ordered) rows.
  static DegreeDaySummary summarize(List<DegreeDayRow> rows) {
    final current = rows.isEmpty ? 0.0 : rows.last.cumulativeGdd;
    DegreeDayThreshold? next;
    for (final threshold in kThresholds) {
      if (current < threshold.degreeDays) {
        next = threshold;
        break;
      }
    }
    return DegreeDaySummary(currentCumulative: current, nextThreshold: next);
  }
}
