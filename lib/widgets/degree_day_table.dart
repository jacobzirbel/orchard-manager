import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/degree_day_view.dart';

/// The spreadsheet: Date | High | Low | DD (day) | DD (cumulative) | Indicator.
///
/// Rows on which a management threshold was first crossed are highlighted and
/// show the action label in the Indicator column. Rows are passed in date
/// order (oldest → newest); the caller handles making the newest visible.
class DegreeDayTable extends StatelessWidget {
  const DegreeDayTable({super.key, required this.rows});

  final List<DegreeDayRow> rows;

  static final _dateFormat = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = theme.colorScheme.tertiaryContainer;
    final onHighlight = theme.colorScheme.onTertiaryContainer;

    return DataTable(
      headingRowColor: WidgetStatePropertyAll(
        theme.colorScheme.surfaceContainerHighest,
      ),
      columnSpacing: 18,
      horizontalMargin: 12,
      columns: const [
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('High'), numeric: true),
        DataColumn(label: Text('Low'), numeric: true),
        DataColumn(label: Text('DD'), numeric: true),
        DataColumn(label: Text('Cum.'), numeric: true),
        DataColumn(label: Text('Indicator')),
      ],
      rows: [
        for (final row in rows)
          DataRow(
            color: row.isThresholdRow
                ? WidgetStatePropertyAll(highlight)
                : null,
            cells: [
              DataCell(Text(_dateFormat.format(row.date))),
              DataCell(Text(row.tMax.toStringAsFixed(0))),
              DataCell(Text(row.tMin.toStringAsFixed(0))),
              DataCell(Text(row.dailyGdd.toStringAsFixed(1))),
              DataCell(Text(
                row.cumulativeGdd.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
              DataCell(
                row.isThresholdRow
                    ? Text(
                        row.crossedThreshold!.label,
                        style: TextStyle(
                          color: onHighlight,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : const Text('—'),
              ),
            ],
          ),
      ],
    );
  }
}
