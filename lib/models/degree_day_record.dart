/// A single day's cached weather observation for a station.
///
/// Stored (keyed by station) in the `station_weather` table — only the raw
/// observed temperatures. It carries no orchard identity: the same day is
/// shared by every orchard/station that references the IEM station. Degree days
/// (per-day and cumulative) are derived on read from the active degree-day
/// model, so they always track the current formula rather than going stale.
class DegreeDayRecord {
  const DegreeDayRecord({
    required this.date,
    required this.tMax,
    required this.tMin,
  });

  /// Calendar date (time component is always midnight / ignored).
  final DateTime date;

  /// Daily maximum temperature in °F.
  final double tMax;

  /// Daily minimum temperature in °F.
  final double tMin;

  /// ISO `yyyy-MM-dd` representation used as part of the table primary key.
  String get dateKey => formatDateKey(date);

  /// Maps the temperature fields; the station/network key columns are supplied
  /// by the database layer, not here.
  Map<String, Object?> toMap() => {
    'date': dateKey,
    't_max': tMax,
    't_min': tMin,
  };

  factory DegreeDayRecord.fromMap(Map<String, Object?> map) => DegreeDayRecord(
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
