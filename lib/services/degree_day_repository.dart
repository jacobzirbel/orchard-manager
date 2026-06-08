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
    this.stations = const [],
    this.selectedStationId,
  });

  /// True when there is a selected orchard with a biofix and at least one
  /// station — i.e. there is something to show.
  final bool isConfigured;
  final List<DegreeDayRow> rows;
  final DegreeDaySummary summary;
  final String? stationId;
  final DateTime? biofix;

  /// All stations in the selected orchard, for the Home station picker.
  final List<Station> stations;
  final String? selectedStationId;

  factory DegreeDayData.unconfigured({
    String? stationId,
    DateTime? biofix,
    List<Station> stations = const [],
    String? selectedStationId,
  }) => DegreeDayData(
    isConfigured: false,
    rows: const [],
    summary: const DegreeDaySummary(currentCumulative: 0),
    stationId: stationId,
    biofix: biofix,
    stations: stations,
    selectedStationId: selectedStationId,
  );
}

/// The per-station standings the comparison screen renders, ordered by progress.
class ComparisonData {
  const ComparisonData({
    this.stations = const [],
    this.orchardName,
    this.hadFetchError = false,
  });

  /// One entry per station in the selected orchard, highest cumulative GDD first.
  final List<StationComparison> stations;

  /// Name of the orchard being compared, shown as the screen subtitle.
  final String? orchardName;

  /// True when refreshing at least one station's weather failed; the screen
  /// still shows every station from cache and warns that data may be stale.
  final bool hadFetchError;
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

  // --- Screen-facing API -----------------------------------------------------

  Future<Orchard?> currentOrchard() async {
    await _ensureMigrated();
    return _selectedOrchard();
  }

  Future<List<DegreeDayThreshold>> currentThresholds() async {
    await _ensureMigrated();
    return (await _selectedOrchard())?.thresholds ?? kThresholds;
  }

  Future<DegreeDayModel> currentModel() async {
    await _ensureMigrated();
    return (await _selectedOrchard())?.model ?? const DegreeDayModel();
  }

  /// Sets the orchard biofix, creating a default orchard on first use. Changing
  /// it never clears the cache — weather is biofix-independent and only filtered
  /// at read (and earlier days backfill on next load).
  Future<void> saveBiofix(DateTime biofix) async {
    await _ensureMigrated();
    final orchard = await _ensureOrchard();
    await _db.upsertOrchard(orchard.copyWith(biofix: dateOnly(biofix)));
  }

  Future<void> saveThresholds(List<DegreeDayThreshold> thresholds) async {
    await _ensureMigrated();
    final orchard = await _ensureOrchard();
    await _db.upsertOrchard(orchard.copyWith(thresholds: thresholds));
  }

  Future<void> saveModel(DegreeDayModel model) async {
    await _ensureMigrated();
    final orchard = await _ensureOrchard();
    await _db.upsertOrchard(orchard.copyWith(model: model));
  }

  // --- Stations (within the selected orchard) --------------------------------

  Future<List<Station>> currentOrchardStations() async {
    await _ensureMigrated();
    final orchard = await _selectedOrchard();
    return orchard == null ? const [] : _db.getStations(orchard.id);
  }

  Future<void> selectStation(String stationId) =>
      _prefs.setSelectedStationId(stationId);

  /// Adds a station to the selected orchard (creating the orchard if needed) and
  /// auto-selects it when it is the orchard's first.
  Future<void> addStation({
    required String iemStation,
    required String network,
    String alias = '',
  }) async {
    await _ensureMigrated();
    final orchard = await _ensureOrchard();
    final existing = await _db.getStations(orchard.id);
    final station = Station(
      id: _uuid.v4(),
      orchardId: orchard.id,
      iemStation: iemStation.trim().toUpperCase(),
      iemNetwork: network.trim().toUpperCase(),
      alias: alias.trim(),
      sortOrder: existing.length,
    );
    await _db.upsertStation(station);
    if (existing.isEmpty) await _prefs.setSelectedStationId(station.id);
  }

  Future<void> updateStation(Station station) async {
    await _db.upsertStation(
      station.copyWith(
        iemStation: station.iemStation.trim().toUpperCase(),
        iemNetwork: station.iemNetwork.trim().toUpperCase(),
        alias: station.alias.trim(),
      ),
    );
  }

  /// Deletes a station; if it was the selected one, falls back to another in the
  /// same orchard so the Home picker always has a valid selection.
  Future<void> deleteStation(String id) async {
    await _ensureMigrated();
    await _db.deleteStation(id);
    if (await _prefs.getSelectedStationId() != id) return;
    final orchard = await _selectedOrchard();
    if (orchard == null) return;
    final remaining = await _db.getStations(orchard.id);
    if (remaining.isNotEmpty) {
      await _prefs.setSelectedStationId(remaining.first.id);
    }
  }

  /// Loads cached rows for the selected station, optionally ensuring weather is
  /// fetched first. Throws [WeatherFetchException] if [fetch] is true and the
  /// network call fails; callers may catch it and render whatever is cached.
  Future<DegreeDayData> load({bool fetch = true}) async {
    await _ensureMigrated();
    final orchard = await _selectedOrchard();
    if (orchard == null) return DegreeDayData.unconfigured();

    final stations = await _db.getStations(orchard.id);
    final station = await _selectedStation(orchard);
    if (orchard.biofix == null || station == null) {
      return DegreeDayData.unconfigured(
        biofix: orchard.biofix,
        stations: stations,
        selectedStationId: station?.id,
      );
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
      stations: stations,
      selectedStationId: station.id,
    );
  }

  /// Loads a side-by-side standing for every station in the selected orchard,
  /// ranked by progress (highest cumulative GDD first). Because biofix, model,
  /// and thresholds are per-orchard, this isolates the weather — apples to apples.
  ///
  /// Like [load] it ensures each station's cache covers `[biofix, today]` when
  /// [fetch] is true, but a fetch failure for one station never blocks the rest:
  /// that station falls back to whatever is already cached and
  /// [ComparisonData.hadFetchError] is set so the caller can warn about staleness.
  Future<ComparisonData> loadComparison({bool fetch = true}) async {
    await _ensureMigrated();
    final orchard = await _selectedOrchard();
    if (orchard == null || orchard.biofix == null) {
      return const ComparisonData();
    }

    final biofix = dateOnly(orchard.biofix!);
    final stations = await _db.getStations(orchard.id);

    var hadFetchError = false;
    final comparisons = <StationComparison>[];
    for (final station in stations) {
      if (fetch) {
        try {
          await _ensureWeather(station, biofix);
        } catch (_) {
          // One station failing to refresh shouldn't blank out the others.
          hadFetchError = true;
        }
      }
      final cached = await _db.getWeather(
        station.iemStation,
        station.iemNetwork,
      );
      // Biofix only filters at read — never accumulate before it.
      final records = cached.where((r) => !r.date.isBefore(biofix)).toList();
      final rows = DegreeDayCalculator.buildRows(
        records,
        thresholds: orchard.thresholds,
        model: orchard.model,
      );
      comparisons.add(
        StationComparison(
          station: station,
          summary: DegreeDayCalculator.summarize(
            rows,
            thresholds: orchard.thresholds,
          ),
          lastDate: rows.isEmpty ? null : rows.last.date,
        ),
      );
    }

    comparisons.sort(
      (a, b) => b.currentCumulative.compareTo(a.currentCumulative),
    );
    return ComparisonData(
      stations: comparisons,
      orchardName: orchard.name,
      hadFetchError: hadFetchError,
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

  /// Returns the selected orchard, creating (and selecting) a default one with
  /// no biofix if none exists yet. Used by the save paths during onboarding.
  Future<Orchard> _ensureOrchard() async {
    final existing = await _selectedOrchard();
    if (existing != null) return existing;
    final orchard = Orchard(id: _uuid.v4(), name: 'My orchard', biofix: null);
    await _db.upsertOrchard(orchard);
    await _prefs.setSelectedOrchardId(orchard.id);
    return orchard;
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
