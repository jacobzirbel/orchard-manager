/// A weather station tracked within an orchard: an IEM station/network pair
/// plus a user-chosen alias. Multiple stations can belong to one orchard, and
/// two stations (in different orchards) may point at the same IEM station —
/// they share the single station-keyed weather cache.
///
/// Maps 1:1 to a row in the `stations` table.
class Station {
  const Station({
    required this.id,
    required this.orchardId,
    required this.iemStation,
    required this.iemNetwork,
    this.alias = '',
    this.sortOrder = 0,
  });

  final String id;
  final String orchardId;

  /// IEM station identifier (e.g. `SAVW3`).
  final String iemStation;

  /// IEM network the station belongs to (e.g. `WI_COOP`).
  final String iemNetwork;

  /// User-friendly name; falls back to the IEM id/network when blank.
  final String alias;
  final int sortOrder;

  String get displayName =>
      alias.trim().isNotEmpty ? alias.trim() : '$iemStation ($iemNetwork)';

  Station copyWith({
    String? iemStation,
    String? iemNetwork,
    String? alias,
    int? sortOrder,
  }) => Station(
    id: id,
    orchardId: orchardId,
    iemStation: iemStation ?? this.iemStation,
    iemNetwork: iemNetwork ?? this.iemNetwork,
    alias: alias ?? this.alias,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'orchard_id': orchardId,
    'iem_station': iemStation,
    'iem_network': iemNetwork,
    'alias': alias,
    'sort_order': sortOrder,
  };

  factory Station.fromMap(Map<String, Object?> map) => Station(
    id: map['id'] as String,
    orchardId: map['orchard_id'] as String,
    iemStation: map['iem_station'] as String,
    iemNetwork: map['iem_network'] as String,
    alias: (map['alias'] as String?) ?? '',
    sortOrder: (map['sort_order'] as int?) ?? 0,
  );
}
