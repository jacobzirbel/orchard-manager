import 'package:flutter_test/flutter_test.dart';
import 'package:orchard_manager/constants/degree_day_constants.dart';
import 'package:orchard_manager/models/degree_day_model.dart';
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

// Most threshold-logic tests below disable the upper cutoff so they can use
// large contrived temps to hit known cumulative totals, keeping the focus on
// the crossing logic rather than the formula.
const _noCutoff = DegreeDayModel(upperCutoffEnabled: false);

void main() {
  group('DegreeDayModel.dailyGdd', () {
    test('simple-average method with base 50', () {
      // avg = (80 + 60) / 2 = 70; 70 - 50 = 20
      expect(const DegreeDayModel().dailyGdd(80, 60), 20);
    });

    test('never goes negative (floors at 0)', () {
      // avg = 40, below base -> clamped to 0
      expect(const DegreeDayModel().dailyGdd(45, 35), 0);
    });

    test('caps the daily high at the upper cutoff when enabled', () {
      // 95 capped to 88: (88 + 65) / 2 - 50 = 26.5 (not 30 uncapped)
      expect(const DegreeDayModel().dailyGdd(95, 65), 26.5);
    });

    test('does not cap when the cutoff is disabled', () {
      expect(_noCutoff.dailyGdd(95, 65), 30);
    });
  });

  group('buildRows', () {
    test('accumulates cumulative and per-day GDD in date order', () {
      final rows = DegreeDayCalculator.buildRows([
        _record('2024-05-03', 90, 70), // daily 30
        _record('2024-05-01', 80, 60), // daily 20
        _record('2024-05-02', 70, 50), // daily 10
      ], model: _noCutoff);

      expect(rows.map((r) => r.dateKeyForTest), [
        '2024-05-01',
        '2024-05-02',
        '2024-05-03',
      ]);
      expect(rows.map((r) => r.dailyGdd), [20, 10, 30]);
      expect(rows.map((r) => r.cumulativeGdd), [20, 30, 60]);
    });

    test('tags the first row to reach a threshold', () {
      const thresholds = [
        DegreeDayThreshold(degreeDays: 250, label: 'first cover spray'),
      ];
      // Two days of 130 GDD each -> cumulative 130, then 260 (crosses 250).
      final rows = DegreeDayCalculator.buildRows(
        [
          _record('2024-05-01', 310, 50), // daily 130
          _record('2024-05-02', 310, 50), // daily 130 -> cum 260
        ],
        thresholds: thresholds,
        model: _noCutoff,
      );

      expect(rows[0].crossedThreshold, isNull);
      expect(rows[1].crossedThreshold?.degreeDays, 250);
      expect(rows[1].crossedThreshold?.label, 'first cover spray');
    });
  });

  group('summarize', () {
    const thresholds = [
      DegreeDayThreshold(degreeDays: 250, label: 'a'),
      DegreeDayThreshold(degreeDays: 500, label: 'b'),
    ];

    test('reports current total, next threshold, and remaining', () {
      final rows = DegreeDayCalculator.buildRows(
        [_record('2024-05-01', 310, 50)], // daily 130
        thresholds: thresholds,
        model: _noCutoff,
      );
      final summary = DegreeDayCalculator.summarize(
        rows,
        thresholds: thresholds,
      );

      expect(summary.currentCumulative, 130);
      expect(summary.nextThreshold?.degreeDays, 250);
      expect(summary.degreeDaysRemaining, 120);
    });

    test('empty data yields zero with the first threshold next', () {
      final summary = DegreeDayCalculator.summarize([], thresholds: thresholds);
      expect(summary.currentCumulative, 0);
      expect(summary.nextThreshold?.degreeDays, 250);
      expect(summary.degreeDaysRemaining, 250);
    });
  });
}

extension on DegreeDayRow {
  String get dateKeyForTest => formatDateKey(date);
}
