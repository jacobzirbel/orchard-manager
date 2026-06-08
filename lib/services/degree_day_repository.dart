import 'package:uuid/uuid.dart';

import '../constants/degree_day_constants.dart';
import '../models/degree_day_model.dart';
import '../models/degree_day_record.dart';
import '../models/degree_day_view.dart';
import '../models/orchard.dart';
import '../models/station.dart';
import 'database_service.dart';
import 'degree_day_calculator.dart';
import 'preferences_service.dart';
import 'weather_service.dart';

/// A contiguous, inclusive date range to fetch from the weather API.
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// Computes the date ranges to fetch so the station's cache covers
/// `[biofix, today]`.
///
/// Because the cache is biofix-independent (raw station weather), this returns:
/// - a **backward** gap when the biofix sits earlier than the oldest cached day
///   (i.e. biofix was moved back and we never fetched those days), and
/// - a **forward** gap from the newest cached day through today (new days, plus
///   a refresh of the last cached day in case it was provisional).
///
/// Pure and side-effect free so it can be unit-tested without a database.
List<DateRange> weatherFetchGaps({
  required DateTime biofix,
  required DateTime today,
  DateTime? cachedMin,
  DateTime? cachedMax,
}) {
  final from = dateOnly(biofix);
  final to = dateOnly(today);
  if (from.isAfter(to)) return const [];
  if (cachedMin == null || cachedMax == null) return [DateRange(from, to)];

  final gaps = <DateRange>[];
  if (from.isBefore(cachedMin)) {
    gaps.add(DateRange(from, cachedMin.subtract(const Duration(days: 1))));
  }
  if (!cachedMax.isAfter(to)) {
    gaps.add(DateRange(cachedMax, to));
  }
  return gaps;
}

/// The configured state + computed rows the UI renders.
class DegreeDayData {
  const DegreeDayData({
    required this.isConfigured,
    required this.rows,
    required this.summary,
    this.stationId,
    this.biofix,
  });

  /// True when there is a selected orchard with a biofix and at least one
  /// station — i.e. there is something to show.
  final bool isConfigured;
  final List<DegreeDayRow> rows;
  final DegreeDaySummary summary;
  final String? stationId;
  final DateTime? biofix;

  factory DegreeDayData.unconfigured({String? stationId, DateTime? biofix}) =>
      DegreeDayData(
        isConfigured: false,
        rows: const [],
        summary: const DegreeDaySummary(currentCumulative: 0),
        stationId: stationId,
        biofix: biofix,
      );
}

/// The single entry point the UI uses. Owns the preferences, database, and
/// weather services and ties them together: ensure weather is cached → derive
/// rows for the selected orchard/station.
class DegreeDayRepository {
  DegreeDayRepository({
    PreferencesService? preferences,
    DatabaseService? database,
    WeatherService? weather,
  }) : _prefs = preferences ?? PreferencesService(),
       _db = database ?? DatabaseService.instance,
       _weather = weather ?? WeatherService();

  final PreferencesService _prefs;
  final DatabaseService _db;
  final WeatherService _weather;

  static const _uuid = Uuid();

  Future<void>? _migration;

  // --- Screen-facing API (one orchard/station today; see Phase 2+ for more) --

  Future<String?> currentStationId() async {
    await _ensureMigrated();
    final orchard = await _selectedOrchard();
    if (orchard == null) return null;
    return (await _selectedStation(orchard))?.iemStation;
  }

  Future<String?> currentNetwork() async {
    await _ensureMigrated();
    final orchard = await _selectedOrchard();
    if (orchard == null) return null;
    return (await _selectedStation(orchard))?.iemNetwork;
  }

  Future<DateTime?> currentBiofix() async {
    await _ensureMigrated();
    return (await _selectedOrchard())?.biofix;
  }

  Future<List<DegreeDayThreshold>> currentThresholds() async {
    await _ensureMigrated();
    return (await _selectedOrchard())?.thresholds ?? kThresholds;
  }

  Future<DegreeDayModel> currentModel() async {
    await _ensureMigrated();
    return (await _selectedOrchard())?.model ?? const DegreeDayModel();
  }

  Future<void> saveThresholds(List<DegreeDayThreshold> thresholds) async {
    await _ensureMigrated();
    final orchard = await _selectedOrchard();
    if (orchard == null) return;
    await _db.upsertOrchard(orchard.copyWith(thresholds: thresholds));
  }

  Future<void> saveModel(DegreeDayModel model) async {
    await _ensureMigrated();
    final orchard = await _selectedOrchard();
    if (orchard == null) return;
    await _db.upsertOrchard(orchard.copyWith(model: model));
  }

  /// Persists the station + biofix, creating the orchard/station on first use.
  /// No cache clearing: weather is keyed by station and biofix only filters at
  /// read, so changing either just recomputes (and may backfill on next load).
  Future<void> saveSettings({
    required String stationId,
    required String network,
    required DateTime biofix,
  }) async {
    await _ensureMigrated();
    final normStation = stationId.trim().toUpperCase();
    final normNetwork = network.trim().toUpperCase();
    final normBiofix = dateOnly(biofix);

    var orchard = await _selectedOrchard();
    if (orchard == null) {
      orchard = Orchard(id: _uuid.v4(), name: 'My orchard', biofix: normBiofix);
      await _db.upsertOrchard(orchard);
      await _prefs.setSelectedOrchardId(orchard.id);
    } else {
      await _db.upsertOrchard(orchard.copyWith(biofix: normBiofix));
    }

    final station = await _selectedStation(orchard);
    if (station == null) {
      final created = Station(
        id: _uuid.v4(),
        orchardId: orchard.id,
        iemStation: normStation,
        iemNetwork: normNetwork,
      );
      await _db.upsertStation(created);
      await _prefs.setSelectedStationId(created.id);
    } else {
      await _db.upsertStation(
        station.copyWith(iemStation: normStation, iemNetwork: normNetwork),
      );
    }
  }

  /// Loads cached rows for the selected station, optionally ensuring weather is
  /// fetched first. Throws [WeatherFetchException] if [fetch] is true and the
  /// network call fails; callers may catch it and render whatever is cached.
  Future<DegreeDayData> load({bool fetch = true}) async {
    await _ensureMigrated();
    final orchard = await _selectedOrchard();
    if (orchard == null || orchard.biofix == null) {
      return DegreeDayData.unconfigured(biofix: orchard?.biofix);
    }
    final station = await _selectedStation(orchard);
    if (station == null) {
      return DegreeDayData.unconfigured(biofix: orchard.biofix);
    }

    final biofix = dateOnly(orchard.biofix!);
    if (fetch) await _ensureWeather(station, biofix);

    final cached = await _db.getWeather(station.iemStation, station.iemNetwork);
    // Biofix only filters at read — never accumulate before it.
    final records = cached.where((r) => !r.date.isBefore(biofix)).toList();
    final rows = DegreeDayCalculator.buildRows(
      records,
      thresholds: orchard.thresholds,
      model: orchard.model,
    );
    return DegreeDayData(
      isConfigured: true,
      rows: rows,
      summary: DegreeDayCalculator.summarize(
        rows,
        thresholds: orchard.thresholds,
      ),
      stationId: station.iemStation,
      biofix: orchard.biofix,
    );
  }

  // --- Internals -------------------------------------------------------------

  /// Fetches whatever is needed so the station cache covers `[biofix, today]`.
  Future<void> _ensureWeather(Station station, DateTime biofix) async {
    final today = dateOnly(DateTime.now());
    final range = await _db.cachedWeatherRange(
      station.iemStation,
      station.iemNetwork,
    );
    final gaps = weatherFetchGaps(
      biofix: biofix,
      today: today,
      cachedMin: range?.min,
      cachedMax: range?.max,
    );
    for (final gap in gaps) {
      final temps = await _weather.fetchDaily(
        stationId: station.iemStation,
        network: station.iemNetwork,
        start: gap.start,
        end: gap.end,
      );
      final records = temps
          .map((t) => DegreeDayRecord(date: t.date, tMax: t.tMax, tMin: t.tMin))
          .toList();
      await _db.upsertWeather(station.iemStation, station.iemNetwork, records);
    }
  }

  Future<Orchard?> _selectedOrchard() async {
    final id = await _prefs.getSelectedOrchardId();
    if (id != null) {
      final orchard = await _db.getOrchard(id);
      if (orchard != null) return orchard;
    }
    final all = await _db.getOrchards();
    if (all.isEmpty) return null;
    await _prefs.setSelectedOrchardId(all.first.id);
    return all.first;
  }

  Future<Station?> _selectedStation(Orchard orchard) async {
    final stations = await _db.getStations(orchard.id);
    if (stations.isEmpty) return null;
    final id = await _prefs.getSelectedStationId();
    final station = stations.firstWhere(
      (s) => s.id == id,
      orElse: () => stations.first,
    );
    if (station.id != id) await _prefs.setSelectedStationId(station.id);
    return station;
  }

  Future<void> _ensureMigrated() => _migration ??= _runMigration();

  /// One-time migration of pre-v3 SharedPreferences config into the database:
  /// folds the single station + biofix + model + thresholds into one orchard
  /// with one station. The old weather cache was already dropped by the schema
  /// upgrade, so it simply refetches on next load.
  Future<void> _runMigration() async {
    if ((await _db.getOrchards()).isNotEmpty) return;

    final stationId = await _prefs.legacyStationId();
    final network = await _prefs.legacyNetwork();
    if (stationId == null || network == null) return; // fresh install

    final orchard = Orchard(
      id: _uuid.v4(),
      name: 'My orchard',
      biofix: await _prefs.legacyBiofix(),
      model: await _prefs.legacyModel(),
      thresholds: await _prefs.legacyThresholds(),
    );
    await _db.upsertOrchard(orchard);
    await _prefs.setSelectedOrchardId(orchard.id);

    final station = Station(
      id: _uuid.v4(),
      orchardId: orchard.id,
      iemStation: stationId,
      iemNetwork: network,
    );
    await _db.upsertStation(station);
    await _prefs.setSelectedStationId(station.id);
  }
}
