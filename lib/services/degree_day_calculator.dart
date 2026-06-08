import '../constants/degree_day_constants.dart';
import '../models/degree_day_model.dart';
import '../models/degree_day_record.dart';
import '../models/degree_day_view.dart';

/// Pure degree-day math. No I/O — kept separate so it is trivially testable.
class DegreeDayCalculator {
  const DegreeDayCalculator();

  /// Builds display rows from stored records: sorts by date, accumulates the
  /// running total, and tags the first row to reach each management threshold.
  ///
  /// [thresholds] defaults to the built-in [kThresholds] but may be a
  /// user-customized set; it is sorted ascending here so callers needn't.
  /// [model] supplies the base temperature and cutoffs used to compute each
  /// day's GDD; it defaults to the standard codling moth model.
  static List<DegreeDayRow> buildRows(
    List<DegreeDayRecord> records, {
    List<DegreeDayThreshold> thresholds = kThresholds,
    DegreeDayModel model = const DegreeDayModel(),
  }) {
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    final ordered = _ascending(thresholds);

    var cumulative = 0.0;
    var nextThresholdIndex = 0;
    DateTime? previousDate;
    final rows = <DegreeDayRow>[];

    for (final record in sorted) {
      // The weather source silently omits days it has no reading for (see
      // WeatherService._parseCsv), so a >1-day jump means the source has a
      // hole here — those days never contributed to `cumulative`.
      final missingDaysBefore = previousDate == null
          ? 0
          : record.date.difference(previousDate).inDays - 1;
      previousDate = record.date;

      final daily = model.dailyGdd(record.tMax, record.tMin);
      cumulative += daily;

      // A single day can cross more than one threshold; attribute the highest
      // one reached on this day so the label reflects the current stage.
      DegreeDayThreshold? crossed;
      while (nextThresholdIndex < ordered.length &&
          cumulative >= ordered[nextThresholdIndex].degreeDays) {
        crossed = ordered[nextThresholdIndex];
        nextThresholdIndex++;
      }

      rows.add(
        DegreeDayRow(
          record: record,
          dailyGdd: daily,
          cumulativeGdd: cumulative,
          crossedThreshold: crossed,
          missingDaysBefore: missingDaysBefore,
        ),
      );
    }

    return rows;
  }

  /// Derives the header summary from the (date-ordered) rows.
  ///
  /// Pass the same [thresholds] used to build the rows.
  static DegreeDaySummary summarize(
    List<DegreeDayRow> rows, {
    List<DegreeDayThreshold> thresholds = kThresholds,
  }) {
    final current = rows.isEmpty ? 0.0 : rows.last.cumulativeGdd;
    DegreeDayThreshold? next;
    for (final threshold in _ascending(thresholds)) {
      if (current < threshold.degreeDays) {
        next = threshold;
        break;
      }
    }
    final missingDays = rows.fold<int>(
      0,
      (sum, row) => sum + row.missingDaysBefore,
    );
    return DegreeDaySummary(
      currentCumulative: current,
      nextThreshold: next,
      missingDays: missingDays,
    );
  }

  static List<DegreeDayThreshold> _ascending(
    List<DegreeDayThreshold> thresholds,
  ) => [...thresholds]..sort((a, b) => a.degreeDays.compareTo(b.degreeDays));
}
