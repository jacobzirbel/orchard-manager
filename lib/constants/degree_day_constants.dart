/// Single source of truth for the codling moth degree-day model.
///
/// Degree days are computed in Fahrenheit with a base (lower threshold)
/// temperature of 50°F, the standard for codling moth (Cydia pomonella).
library;

import 'dart:math' as math;

/// Base temperature in °F below which no development is accumulated.
const double kBaseTempF = 50.0;

/// Growing degree days contributed by a single day: the simple-average method
/// (`(tMax + tMin) / 2 - base`) floored at zero, since development never
/// reverses. Temperatures and the result are in °F.
double dailyGddFor(double tMax, double tMin) =>
    math.max(0.0, (tMax + tMin) / 2.0 - kBaseTempF);

/// A management threshold expressed in cumulative degree days from biofix.
class DegreeDayThreshold {
  const DegreeDayThreshold({required this.degreeDays, required this.label});

  /// Cumulative degree days (from biofix) at which this event occurs.
  final double degreeDays;

  /// The recommended action / biological event at this threshold.
  final String label;
}

/// Codling moth management thresholds, in ascending order.
///
/// These drive both the highlighted rows in the table and the
/// "next threshold" summary in the header.
const List<DegreeDayThreshold> kThresholds = [
  DegreeDayThreshold(
    degreeDays: 250,
    label: '1st gen egg hatch — first cover spray',
  ),
  DegreeDayThreshold(
    degreeDays: 500,
    label: '1st gen peak — second cover spray',
  ),
  DegreeDayThreshold(
    degreeDays: 1000,
    label: '2nd gen biofix — third cover spray',
  ),
  DegreeDayThreshold(
    degreeDays: 1250,
    label: '2nd gen egg hatch — fourth cover spray',
  ),
];
