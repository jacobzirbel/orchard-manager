/// A single day's stored weather observation for one orchard.
///
/// This maps 1:1 to a row in the `degree_days` SQLite table, which stores only
/// the raw observed temperatures. Degree days (per-day and cumulative) are
/// derived on read from the active degree-day model, so they always track the
/// current formula and full history rather than going stale in storage.
class DegreeDayRecord {
  const DegreeDayRecord({
    required this.orchardId,
    required this.date,
    required this.tMax,
    required this.tMin,
  });

  final String orchardId;

  /// Calendar date (time component is always midnight / ignored).
  final DateTime date;

  /// Daily maximum temperature in °F.
  final double tMax;

  /// Daily minimum temperature in °F.
  final double tMin;

  /// ISO `yyyy-MM-dd` representation used as the table primary key.
  String get dateKey => formatDateKey(date);

  Map<String, Object?> toMap() => {
    'orchard_id': orchardId,
    'date': dateKey,
    't_max': tMax,
    't_min': tMin,
  };

  factory DegreeDayRecord.fromMap(Map<String, Object?> map) => DegreeDayRecord(
    orchardId: map['orchard_id'] as String,
    date: DateTime.parse(map['date'] as String),
    tMax: (map['t_max'] as num).toDouble(),
    tMin: (map['t_min'] as num).toDouble(),
  );
}

/// Formats a [DateTime] as a stable `yyyy-MM-dd` key (used for storage + URLs).
String formatDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Strips the time component, returning midnight of the same calendar day.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
