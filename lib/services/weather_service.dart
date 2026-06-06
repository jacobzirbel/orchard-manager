import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/degree_day_record.dart';

/// A single day of observed high/low temperatures from the weather source.
class DailyTemp {
  const DailyTemp({required this.date, required this.tMax, required this.tMin});

  final DateTime date;
  final double tMax;
  final double tMin;
}

/// Thrown when the weather request fails or returns an unusable response.
class WeatherFetchException implements Exception {
  WeatherFetchException(this.message);
  final String message;
  @override
  String toString() => 'WeatherFetchException: $message';
}

/// Fetches daily max/min temperatures from the Iowa Environmental Mesonet (IEM)
/// daily request endpoint. The endpoint only serves CSV, so we parse that
/// directly (no JSON variant available).
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _host = 'mesonet.agron.iastate.edu';
  static const _path = '/cgi-bin/request/daily.py';

  /// Fetches daily temps for [stationId] on [network] from [start] through
  /// [end] (inclusive).
  ///
  /// [network] is the IEM network the station belongs to (e.g. `WI_COOP`,
  /// `IA_ASOS`) — the endpoint rejects the request with HTTP 422 without it.
  /// Rows with a missing/unparseable high or low are skipped. Returns an empty
  /// list if [start] is after [end].
  Future<List<DailyTemp>> fetchDaily({
    required String stationId,
    required String network,
    required DateTime start,
    required DateTime end,
  }) async {
    final from = dateOnly(start);
    final to = dateOnly(end);
    if (from.isAfter(to)) return const [];

    final uri = Uri.https(_host, _path, {
      'station': stationId,
      'network': network,
      'year1': '${from.year}',
      'month1': '${from.month}',
      'day1': '${from.day}',
      'year2': '${to.year}',
      'month2': '${to.month}',
      'day2': '${to.day}',
      // Modern IEM API uses `vars` (comma-separated), not repeated `var`.
      'vars': 'max_tmpf,min_tmpf',
      'what': 'download',
      'delim': 'comma',
      'gis': 'no',
    });

    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw WeatherFetchException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw WeatherFetchException(
        'IEM returned HTTP ${response.statusCode}.',
      );
    }

    return _parseCsv(response.body);
  }

  /// Parses the IEM CSV body into [DailyTemp]s, resolving columns by header
  /// name so the parser is robust to column ordering.
  List<DailyTemp> _parseCsv(String body) {
    final lines = const LineSplitter()
        .convert(body)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];

    final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
    // The IEM response labels the temperature columns `max_temp_f`/`min_temp_f`
    // (not the `max_tmpf`/`min_tmpf` names used in the `vars` request param).
    final dayIdx = header.indexOf('day');
    final maxIdx = header.indexOf('max_temp_f');
    final minIdx = header.indexOf('min_temp_f');

    if (dayIdx < 0 || maxIdx < 0 || minIdx < 0) {
      throw WeatherFetchException(
        'Unexpected CSV format from IEM (check the station ID and network).',
      );
    }

    final maxCol = [dayIdx, maxIdx, minIdx].reduce((a, b) => a > b ? a : b);
    final result = <DailyTemp>[];

    for (final line in lines.skip(1)) {
      final cells = line.split(',');
      if (cells.length <= maxCol) continue;

      final date = DateTime.tryParse(cells[dayIdx].trim());
      final tMax = double.tryParse(cells[maxIdx].trim());
      final tMin = double.tryParse(cells[minIdx].trim());

      // Skip rows with missing/null temps (IEM uses "None"/"M"/empty).
      if (date == null || tMax == null || tMin == null) continue;

      result.add(DailyTemp(date: dateOnly(date), tMax: tMax, tMin: tMin));
    }

    return result;
  }

  void dispose() => _client.close();
}
