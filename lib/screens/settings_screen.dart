import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/degree_day_repository.dart';

/// Settings: the IEM station ID and the biofix date that anchors accumulation.
///
/// Pops `true` when settings were saved so the caller (HomeScreen) knows to
/// reload. Changing either value clears the cache (handled in the repository),
/// so the next load refetches from biofix.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});

  final DegreeDayRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _stationController = TextEditingController();
  final _networkController = TextEditingController();
  final _dateFormat = DateFormat('EEE, MMM d, yyyy');

  DateTime? _biofix;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final stationId = await widget.repository.currentStationId();
    final network = await widget.repository.currentNetwork();
    final biofix = await widget.repository.currentBiofix();
    if (!mounted) return;
    setState(() {
      _stationController.text = stationId ?? '';
      _networkController.text = network ?? '';
      _biofix = biofix;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _stationController.dispose();
    _networkController.dispose();
    super.dispose();
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
    if (picked != null) {
      setState(() => _biofix = picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_biofix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a biofix date.')),
      );
      return;
    }

    setState(() => _saving = true);
    await widget.repository.saveSettings(
      stationId: _stationController.text,
      network: _networkController.text,
      biofix: _biofix!,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _stationController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'IEM station ID',
                      hintText: 'e.g. SAVW3',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cell_tower),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Enter a station ID'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _networkController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'IEM network',
                      hintText: 'e.g. WI_COOP',
                      helperText: 'The network the station belongs to '
                          '(e.g. WI_COOP, IA_ASOS).',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.hub),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Enter a network'
                            : null,
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Changing the station or biofix clears cached data and '
                      'refetches from the new biofix.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
