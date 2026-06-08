import 'package:flutter/material.dart';

import '../models/degree_day_view.dart';

/// Header card above the table: current cumulative DD, the next threshold, and
/// how many degree days remain before it.
class SummaryHeader extends StatelessWidget {
  const SummaryHeader({super.key, required this.summary});

  final DegreeDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = summary.nextThreshold;
    final remaining = summary.degreeDaysRemaining;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  summary.currentCumulative.toStringAsFixed(0),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'cumulative DD',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (summary.missingDays > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    summary.missingDays == 1
                        ? '1 day with no station data — not counted toward the total'
                        : '${summary.missingDays} days with no station data — '
                              'not counted toward the total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (next == null)
              Text(
                'All thresholds reached for the season.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              )
            else ...[
              Text(
                'Next: ${next.label}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${remaining!.toStringAsFixed(0)} DD remaining '
                '(at ${next.degreeDays.toStringAsFixed(0)} DD)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
