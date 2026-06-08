import 'package:flutter_test/flutter_test.dart';
import 'package:orchard_manager/constants/degree_day_constants.dart';
import 'package:orchard_manager/models/degree_day_model.dart';
import 'package:orchard_manager/models/degree_day_record.dart';
import 'package:orchard_manager/services/degree_day_calculator.dart';
import 'package:orchard_manager/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

DegreeDayRecord _record(String date, double tMax, double tMin) =>
    DegreeDayRecord(
      orchardId: 'test',
      date: DateTime.parse(date),
      tMax: tMax,
      tMin: tMin,
    );

// Disable the upper cutoff so the contrived 310°F rows yield a round 130 GDD,
// keeping these tests focused on threshold behavior, not the formula.
const _noCutoff = DegreeDayModel(upperCutoffEnabled: false);

void main() {
  group('DegreeDayThreshold serialization', () {
    test('round-trips through JSON', () {
      const original = DegreeDayThreshold(degreeDays: 250, label: 'spray');
      final restored = DegreeDayThreshold.fromJson(original.toJson());
      expect(restored, original);
    });

    test('value equality compares degreeDays and label', () {
      expect(
        const DegreeDayThreshold(degreeDays: 100, label: 'a'),
        const DegreeDayThreshold(degreeDays: 100, label: 'a'),
      );
      expect(
        const DegreeDayThreshold(degreeDays: 100, label: 'a'),
        isNot(const DegreeDayThreshold(degreeDays: 100, label: 'b')),
      );
    });
  });

  group('calculator with custom thresholds', () {
    test('tags the first row to reach a custom threshold', () {
      const custom = [DegreeDayThreshold(degreeDays: 100, label: 'custom')];
      // 310/50 -> daily 130, crossing the custom 100 on day one.
      final rows = DegreeDayCalculator.buildRows(
        [_record('2024-05-01', 310, 50)],
        thresholds: custom,
        model: _noCutoff,
      );
      expect(rows.single.crossedThreshold?.degreeDays, 100);
      expect(rows.single.crossedThreshold?.label, 'custom');
    });

    test('summarize reports the next custom threshold and remaining', () {
      const custom = [
        DegreeDayThreshold(degreeDays: 100, label: 'a'),
        DegreeDayThreshold(degreeDays: 200, label: 'b'),
      ];
      final rows = DegreeDayCalculator.buildRows(
        [_record('2024-05-01', 310, 50)], // cumulative 130
        thresholds: custom,
        model: _noCutoff,
      );
      final summary = DegreeDayCalculator.summarize(rows, thresholds: custom);
      expect(summary.nextThreshold?.degreeDays, 200);
      expect(summary.degreeDaysRemaining, 70);
    });

    test('accepts thresholds in any order (sorted internally)', () {
      const unsorted = [
        DegreeDayThreshold(degreeDays: 200, label: 'b'),
        DegreeDayThreshold(degreeDays: 100, label: 'a'),
      ];
      final rows = DegreeDayCalculator.buildRows(
        [_record('2024-05-01', 310, 50)], // cumulative 130
        thresholds: unsorted,
        model: _noCutoff,
      );
      // 130 crosses 100 (the lower) but not 200.
      expect(rows.single.crossedThreshold?.degreeDays, 100);
    });
  });

  group('PreferencesService thresholds', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns the built-in defaults when never customized', () async {
      expect(await PreferencesService().getThresholds(), kThresholds);
    });

    test('round-trips a saved custom list', () async {
      final prefs = PreferencesService();
      final custom = [
        const DegreeDayThreshold(degreeDays: 120, label: 'x'),
        const DegreeDayThreshold(degreeDays: 480, label: 'y'),
      ];
      await prefs.setThresholds(custom);
      expect(await prefs.getThresholds(), custom);
    });

    test('honors an explicitly saved empty list', () async {
      final prefs = PreferencesService();
      await prefs.setThresholds([]);
      expect(await prefs.getThresholds(), isEmpty);
    });

    test('falls back to defaults on unparseable data', () async {
      SharedPreferences.setMockInitialValues({'thresholds': 'not json'});
      expect(await PreferencesService().getThresholds(), kThresholds);
    });
  });

  group('PreferencesService model', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to base 50 with the 88°F cutoff on', () async {
      expect(await PreferencesService().getModel(), const DegreeDayModel());
    });

    test('round-trips a saved custom model', () async {
      final prefs = PreferencesService();
      const custom = DegreeDayModel(
        baseTempF: 43,
        upperCutoffEnabled: false,
        upperCutoffTempF: 90,
      );
      await prefs.setModel(custom);
      expect(await prefs.getModel(), custom);
    });
  });
}
