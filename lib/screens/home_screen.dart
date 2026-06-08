import 'package:flutter/material.dart';

import '../services/degree_day_repository.dart';
import '../services/weather_service.dart';
import '../widgets/degree_day_table.dart';
import '../widgets/summary_header.dart';
import 'settings_screen.dart';

/// The main spreadsheet view. Fetches on open, supports pull-to-refresh and a
/// manual refresh button, and routes to Settings for station/biofix config.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final DegreeDayRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _vScrollController = ScrollController();

  DegreeDayData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(isInitial: true);
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  /// Loads cached rows, fetching new days first. On a fetch failure it still
  /// surfaces whatever is cached and shows the error.
  Future<void> _load({required bool isInitial}) async {
    if (isInitial) setState(() => _loading = true);

    DegreeDayData data;
    String? error;
    try {
      data = await widget.repository.load(fetch: true);
    } on WeatherFetchException catch (e) {
      error = e.message;
      data = await widget.repository.load(fetch: false);
    } catch (e) {
      error = 'Something went wrong while refreshing.';
      data = await widget.repository.load(fetch: false);
    }

    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });

    if (error != null) _showError(error);
    _scrollToNewest();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Jumps to the bottom so the newest date is visible after data loads.
  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_vScrollController.hasClients) {
        _vScrollController.jumpTo(_vScrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(repository: widget.repository),
      ),
    );
    if (changed == true) {
      await _load(isInitial: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orchard Manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(isInitial: false),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _selectStation(String stationId) async {
    await widget.repository.selectStation(stationId);
    await _load(isInitial: true);
  }

  /// A header showing the active station — a dropdown when there's more than one
  /// to switch between, or just its name when there's a single station.
  Widget _buildStationBar(DegreeDayData data) {
    if (data.stations.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final selected = data.stations.firstWhere(
      (s) => s.id == data.selectedStationId,
      orElse: () => data.stations.first,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            Icons.cell_tower,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: data.stations.length < 2
                ? Text(selected.displayName, style: theme.textTheme.titleSmall)
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selected.id,
                      items: [
                        for (final station in data.stations)
                          DropdownMenuItem(
                            value: station.id,
                            child: Text(station.displayName),
                          ),
                      ],
                      onChanged: (id) {
                        if (id != null) _selectStation(id);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data;
    if (data == null || !data.isConfigured) {
      return _buildUnconfigured();
    }

    return RefreshIndicator(
      onRefresh: () => _load(isInitial: false),
      child: Column(
        children: [
          _buildStationBar(data),
          SummaryHeader(summary: data.summary),
          Expanded(
            child: data.rows.isEmpty
                ? _buildNoData()
                : SingleChildScrollView(
                    controller: _vScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DegreeDayTable(rows: data.rows),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnconfigured() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.agriculture, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Set up your orchard',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Set a biofix date and add a weather station in settings to start '
              'tracking codling moth degree days.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open settings'),
            ),
          ],
        ),
      ),
    );
  }

  /// Configured but no rows yet — keep it scrollable so pull-to-refresh works.
  Widget _buildNoData() {
    return LayoutBuilder(
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
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No data yet for this station and biofix.\n'
                    'Pull down to refresh.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
