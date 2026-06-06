import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/degree_day_record.dart';

/// Key/value app settings backed by SharedPreferences (the Flutter analogue of
/// Android's Preferences DataStore). Holds the station ID, biofix date, and the
/// orchard ID that every cached row is keyed under.
class PreferencesService {
  static const _kStationId = 'station_id';
  static const _kNetwork = 'network';
  static const _kBiofix = 'biofix_date'; // stored as yyyy-MM-dd
  static const _kOrchardId = 'orchard_id';

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
