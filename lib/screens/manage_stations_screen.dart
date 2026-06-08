import 'package:flutter/material.dart';

import '../models/station.dart';
import '../services/degree_day_repository.dart';

/// Manage the weather stations in the selected orchard: add, alias, edit, and
/// remove. Each action persists immediately and pops `true` (incl. via back) so
/// the caller reloads.
class ManageStationsScreen extends StatefulWidget {
  const ManageStationsScreen({super.key, required this.repository});

  final DegreeDayRepository repository;

  @override
  State<ManageStationsScreen> createState() => _ManageStationsScreenState();
}

class _ManageStationsScreenState extends State<ManageStationsScreen> {
  List<Station> _stations = const [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final stations = await widget.repository.currentOrchardStations();
    if (!mounted) return;
    setState(() {
      _stations = stations;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final result = await _showStationDialog();
    if (result == null) return;
    await widget.repository.addStation(
      iemStation: result.station,
      network: result.network,
      alias: result.alias,
    );
    _changed = true;
    await _reload();
  }

  Future<void> _edit(Station station) async {
    final result = await _showStationDialog(existing: station);
    if (result == null) return;
    await widget.repository.updateStation(
      station.copyWith(
        iemStation: result.station,
        iemNetwork: result.network,
        alias: result.alias,
      ),
    );
    _changed = true;
    await _reload();
  }

  Future<void> _delete(Station station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove station?'),
        content: Text('Remove "${station.displayName}" from this orchard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.deleteStation(station.id);
    _changed = true;
    await _reload();
  }

  Future<({String alias, String station, String network})?> _showStationDialog({
    Station? existing,
  }) {
    return showDialog<({String alias, String station, String network})>(
      context: context,
      builder: (_) => _StationDialog(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Stations')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add station'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _stations.isEmpty
            ? _buildEmpty()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                children: [
                  for (final station in _stations)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.cell_tower),
                        title: Text(station.displayName),
                        subtitle: station.alias.trim().isEmpty
                            ? null
                            : Text(
                                '${station.iemStation} (${station.iemNetwork})',
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _edit(station),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(station),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cell_tower, size: 48),
            const SizedBox(height: 12),
            Text(
              'No stations yet.\nAdd an IEM weather station to track.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Add/edit dialog for a single station. Pops a record of the trimmed values.
class _StationDialog extends StatefulWidget {
  const _StationDialog({this.existing});

  final Station? existing;

  @override
  State<_StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends State<_StationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _alias;
  late final TextEditingController _station;
  late final TextEditingController _network;

  @override
  void initState() {
    super.initState();
    _alias = TextEditingController(text: widget.existing?.alias ?? '');
    _station = TextEditingController(text: widget.existing?.iemStation ?? '');
    _network = TextEditingController(text: widget.existing?.iemNetwork ?? '');
  }

  @override
  void dispose() {
    _alias.dispose();
    _station.dispose();
    _network.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      alias: _alias.text.trim(),
      station: _station.text.trim(),
      network: _network.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add station' : 'Edit station'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _alias,
              decoration: const InputDecoration(
                labelText: 'Alias (optional)',
                hintText: 'e.g. North block',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _station,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'IEM station ID',
                hintText: 'e.g. SAVW3',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a station ID'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _network,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'IEM network',
                hintText: 'e.g. WI_COOP',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a network'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
