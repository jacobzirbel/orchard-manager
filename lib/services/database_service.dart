import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/degree_day_record.dart';

/// SQLite-backed cache of computed degree-day rows.
///
/// Schema (per spec):
/// `degree_days(orchard_id TEXT, date TEXT PRIMARY KEY, t_max REAL,
///  t_min REAL, daily_gdd REAL)`
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'orchard_manager.db';
  static const _table = 'degree_days';

  Database? _db;

  Future<Database> get _database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            orchard_id TEXT NOT NULL,
            date TEXT PRIMARY KEY,
            t_max REAL NOT NULL,
            t_min REAL NOT NULL,
            daily_gdd REAL NOT NULL
          )
        ''');
      },
    );
  }

  /// Inserts records, replacing any existing row for the same date so a
  /// provisional final day can be corrected without creating duplicates.
  Future<void> upsertDays(List<DegreeDayRecord> records) async {
    if (records.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(
        _table,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// All cached days for an orchard, ordered oldest → newest.
  Future<List<DegreeDayRecord>> getDays(String orchardId) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'orchard_id = ?',
      whereArgs: [orchardId],
      orderBy: 'date ASC',
    );
    return rows.map(DegreeDayRecord.fromMap).toList();
  }

  /// The most recent cached date for an orchard, or null if none stored yet.
  Future<DateTime?> getLastStoredDate(String orchardId) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      columns: ['date'],
      where: 'orchard_id = ?',
      whereArgs: [orchardId],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['date'] as String);
  }

  /// Removes all cached rows for an orchard (used when biofix changes).
  Future<void> clearOrchard(String orchardId) async {
    final db = await _database;
    await db.delete(_table, where: 'orchard_id = ?', whereArgs: [orchardId]);
  }
}
