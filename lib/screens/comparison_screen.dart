import 'package:flutter/material.dart';

import '../services/degree_day_repository.dart';
import '../widgets/station_comparison_card.dart';

/// Compares the weather stations within the selected orchard side by side. Every
/// station shares the orchard's biofix, model, and thresholds, so the page
/// isolates how each station's weather is tracking — which blocks are ahead and
/// which are behind. Rows are ranked by cumulative degree days.
class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key, required this.repository});

  final DegreeDayRepository repository;

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  ComparisonData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(isInitial: true);
  }

  /// Loads each station's standing, ensuring weather coverage first. A refresh
  /// failure for some stations still renders the rest from cache.
  Future<void> _load({required bool isInitial}) async {
    if (isInitial) setState(() => _loading = true);

    final data = await widget.repository.loadComparison(fetch: true);

    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });

    if (data.hadFetchError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't refresh some stations — showing cached data.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare stations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(isInitial: false),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data;
    if (data == null || data.stations.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () => _load(isInitial: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (data.orchardName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                data.orchardName!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          for (var i = 0; i < data.stations.length; i++)
            StationComparisonCard(
              comparison: data.stations[i],
              rank: i + 1,
            ),
        ],
      ),
    );
  }

  /// No orchard/biofix or no stations — keep it scrollable so pull-to-refresh
  /// works once the user finishes setup elsewhere.
  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => _load(isInitial: false),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.compare_arrows, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Add a biofix and at least one station to compare.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
