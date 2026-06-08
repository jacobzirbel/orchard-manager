import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/degree_day_repository.dart';
import 'degree_day_model_screen.dart';
import 'manage_stations_screen.dart';

/// Orchard-level settings: the biofix date plus entry points to manage the
/// orchard's stations and its degree-day model.
///
/// Each action persists immediately; the screen pops `true` (even via the back
/// button) when anything changed so HomeScreen knows to reload and recompute.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});

  final DegreeDayRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dateFormat = DateFormat('EEE, MMM d, yyyy');

  DateTime? _biofix;
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final orchard = await widget.repository.currentOrchard();
    if (!mounted) return;
    setState(() {
      _biofix = orchard?.biofix;
      _loading = false;
    });
  }

  Future<void> _pickBiofix() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _biofix ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Select biofix date',
    );
    if (picked == null) return;
    await widget.repository.saveBiofix(picked);
    if (!mounted) return;
    setState(() {
      _biofix = picked;
      _changed = true;
    });
  }

  Future<void> _openStations() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManageStationsScreen(repository: widget.repository),
      ),
    );
    if (changed == true && mounted) setState(() => _changed = true);
  }

  Future<void> _openModel() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DegreeDayModelScreen(repository: widget.repository),
      ),
    );
    if (changed == true && mounted) setState(() => _changed = true);
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
        appBar: AppBar(title: const Text('Settings')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event),
                      title: const Text('Biofix date'),
                      subtitle: Text(
                        _biofix == null
                            ? 'Not set'
                            : _dateFormat.format(_biofix!),
                      ),
                      trailing: TextButton(
                        onPressed: _pickBiofix,
                        child: const Text('Change'),
                      ),
                      onTap: _pickBiofix,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text(
                      'The biofix anchors accumulation and is shared by every '
                      'station in this orchard.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cell_tower),
                      title: const Text('Stations'),
                      subtitle: const Text(
                        'Add and alias the weather stations to track.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openStations,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('Degree-day model'),
                      subtitle: const Text(
                        'Base temp, cutoffs, and spray thresholds.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openModel,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
