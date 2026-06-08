import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/degree_day_constants.dart';
import '../models/degree_day_model.dart';
import '../models/degree_day_record.dart';

/// Key/value app settings backed by SharedPreferences (the Flutter analogue of
/// Android's Preferences DataStore). Holds the station ID, biofix date, the
/// orchard ID that every cached row is keyed under, and the user's management
/// thresholds.
class PreferencesService {
  static const _kStationId = 'station_id';
  static const _kNetwork = 'network';
  static const _kBiofix = 'biofix_date'; // stored as yyyy-MM-dd
  static const _kOrchardId = 'orchard_id';
  static const _kThresholds = 'thresholds'; // JSON array of {degreeDays,label}
  static const _kBaseTemp = 'base_temp_f';
  static const _kUpperCutoffOn = 'upper_cutoff_enabled';
  static const _kUpperCutoffTemp = 'upper_cutoff_f';

  static const _uuid = Uuid();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> getStationId() async {
    final value = (await _prefs).getString(_kStationId)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setStationId(String stationId) async {
    await (await _prefs).setString(_kStationId, stationId.trim().toUpperCase());
  }

  /// The IEM network the station belongs to (e.g. `WI_COOP`, `IA_ASOS`).
  Future<String?> getNetwork() async {
    final value = (await _prefs).getString(_kNetwork)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setNetwork(String network) async {
    await (await _prefs).setString(_kNetwork, network.trim().toUpperCase());
  }

  Future<DateTime?> getBiofix() async {
    final raw = (await _prefs).getString(_kBiofix);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setBiofix(DateTime date) async {
    await (await _prefs).setString(_kBiofix, formatDateKey(dateOnly(date)));
  }

  /// The user's management thresholds, or the built-in [kThresholds] if never
  /// customized. An explicitly-saved empty list is honored (returns `[]`).
  /// Falls back to defaults if the stored value is missing or unparseable.
  Future<List<DegreeDayThreshold>> getThresholds() async {
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

  Future<void> setThresholds(List<DegreeDayThreshold> thresholds) async {
    final encoded = jsonEncode(thresholds.map((t) => t.toJson()).toList());
    await (await _prefs).setString(_kThresholds, encoded);
  }

  /// The user's degree-day model parameters, falling back to the standard
  /// defaults ([kBaseTempF], 88°F cutoff on) for any value not yet set.
  Future<DegreeDayModel> getModel() async {
    final prefs = await _prefs;
    return DegreeDayModel(
      baseTempF: prefs.getDouble(_kBaseTemp) ?? kBaseTempF,
      upperCutoffEnabled: prefs.getBool(_kUpperCutoffOn) ?? true,
      upperCutoffTempF: prefs.getDouble(_kUpperCutoffTemp) ?? kUpperCutoffF,
    );
  }

  Future<void> setModel(DegreeDayModel model) async {
    final prefs = await _prefs;
    await prefs.setDouble(_kBaseTemp, model.baseTempF);
    await prefs.setBool(_kUpperCutoffOn, model.upperCutoffEnabled);
    await prefs.setDouble(_kUpperCutoffTemp, model.upperCutoffTempF);
  }

  /// Returns the persisted orchard ID, generating and storing one on first use.
  Future<String> getOrCreateOrchardId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_kOrchardId);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuid.v4();
    await prefs.setString(_kOrchardId, created);
    return created;
  }
}
