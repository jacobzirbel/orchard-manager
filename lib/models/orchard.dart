import 'dart:convert';

import '../constants/degree_day_constants.dart';
import 'degree_day_model.dart';
import 'degree_day_record.dart' show formatDateKey;

/// A managed orchard: the unit that owns a biofix, a degree-day model, and a
/// set of spray thresholds. It contains one or more weather stations (see
/// `Station`), which all accumulate from this orchard's biofix using this
/// orchard's model — so comparing stations isolates the weather.
///
/// Maps 1:1 to a row in the `orchards` table.
class Orchard {
  const Orchard({
    required this.id,
    required this.name,
    required this.biofix,
    this.model = const DegreeDayModel(),
    this.thresholds = kThresholds,
    this.sortOrder = 0,
  });

  final String id;
  final String name;

  /// Accumulation anchor; null until the user sets it (orchard not yet usable).
  final DateTime? biofix;

  final DegreeDayModel model;
  final List<DegreeDayThreshold> thresholds;
  final int sortOrder;

  Orchard copyWith({
    String? name,
    DateTime? biofix,
    DegreeDayModel? model,
    List<DegreeDayThreshold>? thresholds,
    int? sortOrder,
  }) => Orchard(
    id: id,
    name: name ?? this.name,
    biofix: biofix ?? this.biofix,
    model: model ?? this.model,
    thresholds: thresholds ?? this.thresholds,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'biofix': biofix == null ? null : formatDateKey(biofix!),
    'base_temp': model.baseTempF,
    'upper_cutoff_enabled': model.upperCutoffEnabled ? 1 : 0,
    'upper_cutoff_f': model.upperCutoffTempF,
    'thresholds': jsonEncode(thresholds.map((t) => t.toJson()).toList()),
    'sort_order': sortOrder,
  };

  factory Orchard.fromMap(Map<String, Object?> map) {
    final biofixRaw = map['biofix'] as String?;
    final decoded = jsonDecode(map['thresholds'] as String) as List<dynamic>;
    return Orchard(
      id: map['id'] as String,
      name: map['name'] as String,
      biofix: biofixRaw == null ? null : DateTime.parse(biofixRaw),
      model: DegreeDayModel(
        baseTempF: (map['base_temp'] as num).toDouble(),
        upperCutoffEnabled: (map['upper_cutoff_enabled'] as int) == 1,
        upperCutoffTempF: (map['upper_cutoff_f'] as num).toDouble(),
      ),
      thresholds: decoded
          .map((e) => DegreeDayThreshold.fromJson(e as Map<String, dynamic>))
          .toList(),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
