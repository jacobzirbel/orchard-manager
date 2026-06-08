import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/degree_day_record.dart';
import '../models/orchard.dart';
import '../models/station.dart';

/// SQLite store for the app.
///
/// Three tables:
/// - `station_weather` — the raw daily high/low cache, keyed by IEM station +
///   network + date and shared across every orchard. This is the only thing we
///   fetch from the network; everything else is derived from it on read.
/// - `orchards` — per-orchard config: name, biofix, degree-day model, and the
///   spray thresholds (JSON).
/// - `stations` — the IEM stations belonging to each orchard, with aliases.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'orchard_manager.db';
  static const _weather = 'station_weather';
  static const _orchards = 'orchards';
  static const _stations = 'stations';

  Database? _db;

  Future<Database> get _database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) => _createSchema(db),
      // v3 restructured everything: weather is now cached per station (not per
      // orchard) and config moved from SharedPreferences into the DB. The old
      // `degree_days` table was just a cache, so we drop it and let the new
      // station-keyed cache refill from the API on next load.
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS degree_days');
        await _createSchema(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $_weather (
        iem_station TEXT NOT NULL,
        iem_network TEXT NOT NULL,
        date TEXT NOT NULL,
        t_max REAL NOT NULL,
        t_min REAL NOT NULL,
        PRIMARY KEY (iem_station, iem_network, date)
      )
    ''');
    await db.execute('''
      CREATE TABLE $_orchards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        biofix TEXT,
        base_temp REAL NOT NULL,
        upper_cutoff_enabled INTEGER NOT NULL,
        upper_cutoff_f REAL NOT NULL,
        thresholds TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE $_stations (
        id TEXT PRIMARY KEY,
        orchard_id TEXT NOT NULL,
        iem_station TEXT NOT NULL,
        iem_network TEXT NOT NULL,
        alias TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // --- Weather cache (shared, station-keyed) ---------------------------------

  /// Inserts/updates cached observations for one station, replacing any existing
  /// row for the same date so a provisional final day can be corrected.
  Future<void> upsertWeather(
    String iemStation,
    String iemNetwork,
    List<DegreeDayRecord> days,
  ) async {
    if (days.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final day in days) {
      batch.insert(_weather, {
        'iem_station': iemStation,
        'iem_network': iemNetwork,
        ...day.toMap(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// All cached days for a station, oldest → newest.
  Future<List<DegreeDayRecord>> getWeather(
    String iemStation,
    String iemNetwork,
  ) async {
    final db = await _database;
    final rows = await db.query(
      _weather,
      where: 'iem_station = ? AND iem_network = ?',
      whereArgs: [iemStation, iemNetwork],
      orderBy: 'date ASC',
    );
    return rows.map(DegreeDayRecord.fromMap).toList();
  }

  /// The earliest and latest cached dates for a station, or null if none.
  Future<({DateTime min, DateTime max})?> cachedWeatherRange(
    String iemStation,
    String iemNetwork,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT MIN(date) AS lo, MAX(date) AS hi FROM $_weather '
      'WHERE iem_station = ? AND iem_network = ?',
      [iemStation, iemNetwork],
    );
    final lo = rows.first['lo'] as String?;
    final hi = rows.first['hi'] as String?;
    if (lo == null || hi == null) return null;
    return (min: DateTime.parse(lo), max: DateTime.parse(hi));
  }

  // --- Orchards --------------------------------------------------------------

  Future<List<Orchard>> getOrchards() async {
    final db = await _database;
    final rows = await db.query(_orchards, orderBy: 'sort_order ASC, name ASC');
    return rows.map(Orchard.fromMap).toList();
  }

  Future<Orchard?> getOrchard(String id) async {
    final db = await _database;
    final rows = await db.query(
      _orchards,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Orchard.fromMap(rows.first);
  }

  Future<void> upsertOrchard(Orchard orchard) async {
    final db = await _database;
    await db.insert(
      _orchards,
      orchard.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Stations --------------------------------------------------------------

  Future<List<Station>> getStations(String orchardId) async {
    final db = await _database;
    final rows = await db.query(
      _stations,
      where: 'orchard_id = ?',
      whereArgs: [orchardId],
      orderBy: 'sort_order ASC, alias ASC',
    );
    return rows.map(Station.fromMap).toList();
  }

  Future<Station?> getStation(String id) async {
    final db = await _database;
    final rows = await db.query(
      _stations,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Station.fromMap(rows.first);
  }

  Future<void> upsertStation(Station station) async {
    final db = await _database;
    await db.insert(
      _stations,
      station.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteStation(String id) async {
    final db = await _database;
    await db.delete(_stations, where: 'id = ?', whereArgs: [id]);
  }
}
