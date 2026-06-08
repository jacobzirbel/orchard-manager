import 'package:flutter_test/flutter_test.dart';
import 'package:orchard_manager/constants/degree_day_constants.dart';
import 'package:orchard_manager/models/degree_day_record.dart';
import 'package:orchard_manager/models/degree_day_view.dart';
import 'package:orchard_manager/services/degree_day_calculator.dart';

DegreeDayRecord _record(String date, double tMax, double tMin) =>
    DegreeDayRecord(
      orchardId: 'test',
      date: DateTime.parse(date),
      tMax: tMax,
      tMin: tMin,
    );

void main() {
  group('dailyGddFor', () {
    test('uses simple-average method with base 50', () {
      // avg = (80 + 60) / 2 = 70; 70 - 50 = 20
      expect(dailyGddFor(80, 60), 20);
    });

    test('never goes negative (floors at 0)', () {
      // avg = 40, below base -> clamped to 0
      expect(dailyGddFor(45, 35), 0);
    });
  });

  group('buildRows', () {
    test('accumulates cumulative GDD in date order', () {
      final rows = DegreeDayCalculator.buildRows([
        _record('2024-05-03', 90, 70), // daily 30
        _record('2024-05-01', 80, 60), // daily 20
        _record('2024-05-02', 70, 50), // daily 10
      ]);

      expect(rows.map((r) => r.dateKeyForTest), [
        '2024-05-01',
        '2024-05-02',
        '2024-05-03',
      ]);
      expect(rows.map((r) => r.cumulativeGdd), [20, 30, 60]);
    });

    test('tags the first row to reach the 250 DD threshold', () {
      // Two days of 130 GDD each -> cumulative 130, then 260 (crosses 250).
      final rows = DegreeDayCalculator.buildRows([
        _record('2024-05-01', 310, 50), // daily 130
        _record('2024-05-02', 310, 50), // daily 130 -> cum 260
      ]);

      expect(rows[0].crossedThreshold, isNull);
      expect(rows[1].crossedThreshold?.degreeDays, 250);
      expect(rows[1].crossedThreshold?.label, contains('first cover spray'));
    });
  });

  group('summarize', () {
    test('reports current total, next threshold, and remaining', () {
      final rows = DegreeDayCalculator.buildRows([
        _record('2024-05-01', 310, 50), // daily 130
      ]);
      final summary = DegreeDayCalculator.summarize(rows);

      expect(summary.currentCumulative, 130);
      expect(summary.nextThreshold?.degreeDays, 250);
      expect(summary.degreeDaysRemaining, 120);
    });

    test('empty data yields zero with the first threshold next', () {
      final summary = DegreeDayCalculator.summarize([]);
      expect(summary.currentCumulative, 0);
      expect(summary.nextThreshold?.degreeDays, 250);
      expect(summary.degreeDaysRemaining, 250);
    });
  });
}

extension on DegreeDayRow {
  String get dateKeyForTest => formatDateKey(date);
}
