import 'package:flutter_test/flutter_test.dart';
import 'package:orchard_manager/services/degree_day_repository.dart';

void main() {
  group('weatherFetchGaps', () {
    final biofix = DateTime(2025, 5, 1);
    final today = DateTime(2025, 5, 10);

    test('empty cache fetches the whole [biofix, today] range', () {
      final gaps = weatherFetchGaps(biofix: biofix, today: today);
      expect(gaps, hasLength(1));
      expect(gaps.single.start, biofix);
      expect(gaps.single.end, today);
    });

    test('only a forward gap when the cache starts at biofix', () {
      final gaps = weatherFetchGaps(
        biofix: biofix,
        today: today,
        cachedMin: biofix,
        cachedMax: DateTime(2025, 5, 8),
      );
      expect(gaps, hasLength(1));
      // Re-fetches the last cached day (provisional) through today.
      expect(gaps.single.start, DateTime(2025, 5, 8));
      expect(gaps.single.end, today);
    });

    test('moving biofix backward triggers a backward fetch', () {
      final gaps = weatherFetchGaps(
        biofix: DateTime(2025, 4, 20),
        today: today,
        cachedMin: DateTime(2025, 5, 1),
        cachedMax: today,
      );
      expect(gaps, hasLength(2));
      // Backward gap: the days before the oldest cached day.
      expect(gaps.first.start, DateTime(2025, 4, 20));
      expect(gaps.first.end, DateTime(2025, 4, 30));
      // Forward gap: refresh the last cached day.
      expect(gaps.last.start, today);
      expect(gaps.last.end, today);
    });

    test('fully cached through today still refreshes the last day', () {
      final gaps = weatherFetchGaps(
        biofix: biofix,
        today: today,
        cachedMin: biofix,
        cachedMax: today,
      );
      expect(gaps, hasLength(1));
      expect(gaps.single.start, today);
      expect(gaps.single.end, today);
    });

    test('nothing to fetch when biofix is after today', () {
      final gaps = weatherFetchGaps(biofix: DateTime(2025, 6, 1), today: today);
      expect(gaps, isEmpty);
    });
  });
}
