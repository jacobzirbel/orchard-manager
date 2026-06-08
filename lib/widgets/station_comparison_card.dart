import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/degree_day_view.dart';

/// One row on the comparison page: a station's rank, name, current cumulative
/// degree days, the next threshold and how far off it is, and the date of its
/// most recent observation.
class StationComparisonCard extends StatelessWidget {
  const StationComparisonCard({
    super.key,
    required this.comparison,
    required this.rank,
  });

  final StationComparison comparison;

  /// 1-based position once stations are ordered by progress.
  final int rank;

  static final _dateFormat = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = comparison.summary;
    final next = summary.nextThreshold;
    final remaining = summary.degreeDaysRemaining;
    final lastDate = comparison.lastDate;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                '$rank',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comparison.station.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (next == null)
                    Text(
                      'All thresholds reached.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else ...[
                    Text(
                      'Next: ${next.label}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${remaining!.toStringAsFixed(0)} DD to go '
                      '(at ${next.degreeDays.toStringAsFixed(0)})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    lastDate == null
                        ? 'No data yet'
                        : 'Last data: ${_dateFormat.format(lastDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  summary.currentCumulative.toStringAsFixed(0),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'cum. DD',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
