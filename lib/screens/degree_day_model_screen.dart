import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/degree_day_constants.dart';
import '../models/degree_day_model.dart';
import '../services/degree_day_repository.dart';

/// Editor for the whole degree-day model: the calculation parameters (base
/// temperature + upper cutoff) and the management thresholds.
///
/// Everything on screen is a working draft; nothing is persisted until Save,
/// which writes both the model and the thresholds and pops `true` so the caller
/// can recompute. Neither affects cached temperatures, so no refetch is needed.
class DegreeDayModelScreen extends StatefulWidget {
  const DegreeDayModelScreen({super.key, required this.repository});

  final DegreeDayRepository repository;

  @override
  State<DegreeDayModelScreen> createState() => _DegreeDayModelScreenState();
}

class _DegreeDayModelScreenState extends State<DegreeDayModelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseController = TextEditingController();
  final _cutoffController = TextEditingController();
  final List<_ThresholdDraft> _drafts = [];

  bool _upperCutoffEnabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final model = await widget.repository.currentModel();
    final thresholds = await widget.repository.currentThresholds();
    if (!mounted) return;
    setState(() {
      _applyModel(model);
      _replaceDrafts(thresholds);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _baseController.dispose();
    _cutoffController.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _applyModel(DegreeDayModel model) {
    _baseController.text = _formatNumber(model.baseTempF);
    _cutoffController.text = _formatNumber(model.upperCutoffTempF);
    _upperCutoffEnabled = model.upperCutoffEnabled;
  }

  /// Disposes the current drafts and rebuilds the list from [thresholds].
  void _replaceDrafts(List<DegreeDayThreshold> thresholds) {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _drafts
      ..clear()
      ..addAll(thresholds.map(_ThresholdDraft.from));
  }

  void _addThreshold() {
    setState(() => _drafts.add(_ThresholdDraft.empty()));
  }

  void _removeThreshold(_ThresholdDraft draft) {
    setState(() {
      _drafts.remove(draft);
      draft.dispose();
    });
  }

  void _resetToDefaults() {
    setState(() {
      _applyModel(const DegreeDayModel());
      _replaceDrafts(kThresholds);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to defaults — tap Save to apply.')),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final model = DegreeDayModel(
      baseTempF: double.parse(_baseController.text.trim()),
      upperCutoffEnabled: _upperCutoffEnabled,
      // Keep the entered value even when the cutoff is off, so toggling it back
      // on restores it; fall back to the default if the field is blank.
      upperCutoffTempF:
          double.tryParse(_cutoffController.text.trim()) ?? kUpperCutoffF,
    );
    final thresholds = _drafts.map((d) => d.toThreshold()).toList()
      ..sort((a, b) => a.degreeDays.compareTo(b.degreeDays));

    setState(() => _saving = true);
    await widget.repository.saveModel(model);
    await widget.repository.saveThresholds(thresholds);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Degree-day model'),
        actions: [
          TextButton(
            onPressed: _loading || _saving ? null : _resetToDefaults,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Calculation', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _baseController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Base temperature (°F)',
                      helperText:
                          'Lower threshold; subtracted from each day’s '
                          'average.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.thermostat),
                    ),
                    validator: _temperatureValidator,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Upper cutoff'),
                    subtitle: const Text(
                      'Cap the daily high before averaging (codling moth '
                      'standard).',
                    ),
                    value: _upperCutoffEnabled,
                    onChanged: (value) =>
                        setState(() => _upperCutoffEnabled = value),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cutoffController,
                    enabled: _upperCutoffEnabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Upper cutoff (°F)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.arrow_upward),
                    ),
                    validator: (value) => _upperCutoffEnabled
                        ? _temperatureValidator(value)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A day that averages below the base contributes 0 '
                          'degree days — accumulation is never negative. This '
                          'is built into the calculation and can’t be '
                          'turned off.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  Text('Spray thresholds', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Cumulative degree days from biofix at which each action is '
                    'recommended.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_drafts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No thresholds. Add one or reset.'),
                      ),
                    ),
                  for (final draft in _drafts)
                    _ThresholdCard(
                      key: ObjectKey(draft),
                      draft: draft,
                      onRemove: () => _removeThreshold(draft),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addThreshold,
                    icon: const Icon(Icons.add),
                    label: const Text('Add threshold'),
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

String? _temperatureValidator(String? value) {
  final parsed = double.tryParse(value?.trim() ?? '');
  if (parsed == null) return 'Enter a number';
  return null;
}

/// One editable threshold row: a label field plus a degree-days field.
class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({
    super.key,
    required this.draft,
    required this.onRemove,
  });

  final _ThresholdDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: draft.labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g. 1st flight egg hatch',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: TextFormField(
                controller: draft.degreeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'DD',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null) return 'Number';
                  if (parsed < 0) return '≥ 0';
                  return null;
                },
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mutable backing state for one threshold being edited.
class _ThresholdDraft {
  _ThresholdDraft({required String degrees, required String label})
    : degreeController = TextEditingController(text: degrees),
      labelController = TextEditingController(text: label);

  factory _ThresholdDraft.empty() => _ThresholdDraft(degrees: '', label: '');

  factory _ThresholdDraft.from(DegreeDayThreshold threshold) => _ThresholdDraft(
    degrees: _formatNumber(threshold.degreeDays),
    label: threshold.label,
  );

  final TextEditingController degreeController;
  final TextEditingController labelController;

  /// Builds a threshold from the current field values. Only call after the form
  /// has validated, so the parse below is guaranteed to succeed.
  DegreeDayThreshold toThreshold() => DegreeDayThreshold(
    degreeDays: double.parse(degreeController.text.trim()),
    label: labelController.text.trim(),
  );

  void dispose() {
    degreeController.dispose();
    labelController.dispose();
  }
}

/// Drops a trailing `.0` so whole numbers show as e.g. `250`, not `250.0`.
String _formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
