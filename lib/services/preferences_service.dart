import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/degree_day_constants.dart';
import '../models/degree_day_model.dart';

/// Small key/value store (SharedPreferences) for UI selection state — which
/// orchard and station the user is currently viewing.
///
/// It also exposes read-only access to the pre-v3 config keys (station, biofix,
/// thresholds, model), which used to live here. Those are consumed exactly once
/// by the one-time migration into the database; nothing writes them anymore.
class PreferencesService {
  // Current keys.
  static const _kSelectedOrchard = 'selected_orchard_id';
  static const _kSelectedStation = 'selected_station_id';

  // Legacy keys (pre-v3) — read only, for migration.
  static const _kStationId = 'station_id';
  static const _kNetwork = 'network';
  static const _kBiofix = 'biofix_date';
  static const _kThresholds = 'thresholds';
  static const _kBaseTemp = 'base_temp_f';
  static const _kUpperCutoffOn = 'upper_cutoff_enabled';
  static const _kUpperCutoffTemp = 'upper_cutoff_f';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // --- Selection state -------------------------------------------------------

  Future<String?> getSelectedOrchardId() async =>
      (await _prefs).getString(_kSelectedOrchard);

  Future<void> setSelectedOrchardId(String id) async {
    await (await _prefs).setString(_kSelectedOrchard, id);
  }

  Future<String?> getSelectedStationId() async =>
      (await _prefs).getString(_kSelectedStation);

  Future<void> setSelectedStationId(String id) async {
    await (await _prefs).setString(_kSelectedStation, id);
  }

  // --- Legacy config (migration only) ---------------------------------------

  Future<String?> legacyStationId() async {
    final value = (await _prefs).getString(_kStationId)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<String?> legacyNetwork() async {
    final value = (await _prefs).getString(_kNetwork)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<DateTime?> legacyBiofix() async {
    final raw = (await _prefs).getString(_kBiofix);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<List<DegreeDayThreshold>> legacyThresholds() async {
    final raw = (await _prefs).getString(_kThresholds);
    if (raw == null) return kThresholds;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => DegreeDayThreshold.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return kThresholds;
    }
  }

  Future<DegreeDayModel> legacyModel() async {
    final prefs = await _prefs;
    return DegreeDayModel(
      baseTempF: prefs.getDouble(_kBaseTemp) ?? kBaseTempF,
      upperCutoffEnabled: prefs.getBool(_kUpperCutoffOn) ?? true,
      upperCutoffTempF: prefs.getDouble(_kUpperCutoffTemp) ?? kUpperCutoffF,
    );
  }
}
