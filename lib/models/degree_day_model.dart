import 'dart:math' as math;

import '../constants/degree_day_constants.dart';

/// The user-tunable degree-day model parameters plus the single-day GDD formula.
///
/// Defaults match the codling moth standard: base 50°F with an 88°F horizontal
/// upper cutoff applied to the daily high. The result is always floored at zero
/// — a day averaging below the base contributes 0, never a negative value.
/// (That floor is intrinsic to growing degree days, so it is not configurable.)
class DegreeDayModel {
  const DegreeDayModel({
    this.baseTempF = kBaseTempF,
    this.upperCutoffEnabled = true,
    this.upperCutoffTempF = kUpperCutoffF,
  });

  /// Lower developmental threshold (°F); subtracted from each day's average.
  final double baseTempF;

  /// When true, the daily high is capped at [upperCutoffTempF] before averaging.
  final bool upperCutoffEnabled;

  /// Horizontal upper cutoff (°F) applied to the daily high when enabled.
  final double upperCutoffTempF;

  /// Growing degree days contributed by a single day, floored at zero.
  double dailyGdd(double tMax, double tMin) {
    final high = upperCutoffEnabled ? math.min(tMax, upperCutoffTempF) : tMax;
    return math.max(0.0, (high + tMin) / 2.0 - baseTempF);
  }

  @override
  bool operator ==(Object other) =>
      other is DegreeDayModel &&
      other.baseTempF == baseTempF &&
      other.upperCutoffEnabled == upperCutoffEnabled &&
      other.upperCutoffTempF == upperCutoffTempF;

  @override
  int get hashCode =>
      Object.hash(baseTempF, upperCutoffEnabled, upperCutoffTempF);
}
