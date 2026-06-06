import '../models/degree_day_record.dart';
import '../models/degree_day_view.dart';
import 'database_service.dart';
import 'degree_day_calculator.dart';
import 'preferences_service.dart';
import 'weather_service.dart';

/// The configured state + computed rows the UI renders.
class DegreeDayData {
  const DegreeDayData({
    required this.isConfigured,
    required this.rows,
    required this.summary,
    this.stationId,
    this.biofix,
  });

  /// Both a station ID and a biofix date have been set.
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
/// weather services and ties them together: fetch new days → cache → compute.
class DegreeDayRepository {
  DegreeDayRepository({
    PreferencesService? preferences,
    DatabaseService? database,
    WeatherService? weather,
  })  : _prefs = preferences ?? PreferencesService(),
        _db = database ?? DatabaseService.instance,
        _weather = weather ?? WeatherService();

  final PreferencesService _prefs;
  final DatabaseService _db;
  final WeatherService _weather;

  Future<String?> currentStationId() => _prefs.getStationId();
  Future<String?> currentNetwork() => _prefs.getNetwork();
  Future<DateTime?> currentBiofix() => _prefs.getBiofix();

  /// Loads cached rows, optionally fetching any days not yet cached first.
  ///
  /// Used for both the initial open and pull-to-refresh. Throws
  /// [WeatherFetchException] if [fetch] is true and the network call fails;
  /// callers may catch it and still render whatever is cached.
  Future<DegreeDayData> load({bool fetch = true}) async {
    final stationId = await _prefs.getStationId();
    final network = await _prefs.getNetwork();
    final biofix = await _prefs.getBiofix();
    if (stationId == null || network == null || biofix == null) {
      return DegreeDayData.unconfigured(stationId: stationId, biofix: biofix);
    }

    final orchardId = await _prefs.getOrCreateOrchardId();
    if (fetch) {
      await _fetchNewDays(
        orchardId: orchardId,
        stationId: stationId,
        network: network,
        biofix: dateOnly(biofix),
      );
    }

    final records = await _db.getDays(orchardId);
    final rows = DegreeDayCalculator.buildRows(records);
    return DegreeDayData(
      isConfigured: true,
      rows: rows,
      summary: DegreeDayCalculator.summarize(rows),
      stationId: stationId,
      biofix: biofix,
    );
  }

  /// Fetches only the days not already cached (last-stored date forward), maps
  /// them to records with computed daily GDD, and upserts them.
  Future<void> _fetchNewDays({
    required String orchardId,
    required String stationId,
    required String network,
    required DateTime biofix,
  }) async {
    final today = dateOnly(DateTime.now());
    final lastStored = await _db.getLastStoredDate(orchardId);

    // Start at the last cached day (inclusive) so a previously-provisional
    // final day gets refreshed; if nothing is cached yet, start at biofix.
    final start = lastStored ?? biofix;
    if (start.isAfter(today)) return;

    final temps = await _weather.fetchDaily(
      stationId: stationId,
      network: network,
      start: start,
      end: today,
    );

    final records = temps
        .where((t) => !t.date.isBefore(biofix)) // never accumulate before biofix
        .map((t) => DegreeDayRecord(
              orchardId: orchardId,
              date: t.date,
              tMax: t.tMax,
              tMin: t.tMin,
              dailyGdd: DegreeDayCalculator.dailyGdd(t.tMax, t.tMin),
            ))
        .toList();

    await _db.upsertDays(records);
  }

  /// Persists settings. If the station ID or biofix changed, the cached rows no
  /// longer represent the current configuration, so they are cleared; the next
  /// [load] will refetch from biofix.
  Future<void> saveSettings({
    required String stationId,
    required String network,
    required DateTime biofix,
  }) async {
    final orchardId = await _prefs.getOrCreateOrchardId();
    final previousStation = await _prefs.getStationId();
    final previousNetwork = await _prefs.getNetwork();
    final previousBiofix = await _prefs.getBiofix();

    final normalizedStation = stationId.trim().toUpperCase();
    final normalizedNetwork = network.trim().toUpperCase();
    final normalizedBiofix = dateOnly(biofix);

    final stationChanged = previousStation != normalizedStation;
    final networkChanged = previousNetwork != normalizedNetwork;
    final biofixChanged = previousBiofix == null ||
        !_sameDay(dateOnly(previousBiofix), normalizedBiofix);

    await _prefs.setStationId(normalizedStation);
    await _prefs.setNetwork(normalizedNetwork);
    await _prefs.setBiofix(normalizedBiofix);

    if (stationChanged || networkChanged || biofixChanged) {
      await _db.clearOrchard(orchardId);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
