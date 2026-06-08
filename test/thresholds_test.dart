import 'package:flutter_test/flutter_test.dart';
import 'package:orchard_manager/constants/degree_day_constants.dart';
import 'package:orchard_manager/models/degree_day_model.dart';
import 'package:orchard_manager/models/degree_day_record.dart';
import 'package:orchard_manager/models/orchard.dart';
import 'package:orchard_manager/models/station.dart';
import 'package:orchard_manager/services/degree_day_calculator.dart';

DegreeDayRecord _record(String date, double tMax, double tMin) =>
    DegreeDayRecord(date: DateTime.parse(date), tMax: tMax, tMin: tMin);

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

  group('Orchard serialization', () {
    test('round-trips name, biofix, model, and thresholds', () {
      final orchard = Orchard(
        id: 'o1',
        name: 'North block',
        biofix: DateTime(2025, 5, 13),
        model: const DegreeDayModel(
          baseTempF: 50,
          upperCutoffEnabled: true,
          upperCutoffTempF: 88,
        ),
        thresholds: const [
          DegreeDayThreshold(degreeDays: 250, label: 'first cover'),
          DegreeDayThreshold(degreeDays: 1400, label: 'second cover'),
        ],
      );
      final restored = Orchard.fromMap(orchard.toMap());
      expect(restored.id, 'o1');
      expect(restored.name, 'North block');
      expect(restored.biofix, DateTime(2025, 5, 13));
      expect(restored.model, orchard.model);
      expect(restored.thresholds, orchard.thresholds);
    });

    test('handles a null biofix', () {
      final orchard = Orchard(id: 'o2', name: 'x', biofix: null);
      expect(Orchard.fromMap(orchard.toMap()).biofix, isNull);
    });
  });

  group('Station', () {
    test('round-trips through its map', () {
      const station = Station(
        id: 's1',
        orchardId: 'o1',
        iemStation: 'SAVW3',
        iemNetwork: 'WI_COOP',
        alias: 'River trap',
      );
      final restored = Station.fromMap(station.toMap());
      expect(restored.id, 's1');
      expect(restored.orchardId, 'o1');
      expect(restored.iemStation, 'SAVW3');
      expect(restored.iemNetwork, 'WI_COOP');
      expect(restored.alias, 'River trap');
    });

    test('displayName falls back to id/network when alias is blank', () {
      const station = Station(
        id: 's2',
        orchardId: 'o1',
        iemStation: 'SAVW3',
        iemNetwork: 'WI_COOP',
      );
      expect(station.displayName, 'SAVW3 (WI_COOP)');
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
}
