import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orchard_manager/services/weather_service.dart';

/// A trimmed sample of a real IEM daily.py response: the temperature columns
/// are named `max_temp_f`/`min_temp_f`, extra columns follow, and missing
/// values appear as the literal `None`.
const _sampleCsv = '''
station,day,max_temp_f,min_temp_f,max_dewpoint_f,precip_in,climo_high_f
SAVW3,2025-05-01,50.0,35.0,None,0.07,58.2
SAVW3,2025-05-02,51.0,43.0,None,0.57,58.6
SAVW3,2025-05-03,None,40.0,None,0.00,59.0
SAVW3,2025-05-04,62.0,None,None,0.00,59.4
''';

void main() {
  test('parses IEM CSV, mapping max_temp_f/min_temp_f and skipping None rows',
      () async {
    final client = MockClient((request) async => http.Response(_sampleCsv, 200));
    final service = WeatherService(client: client);

    final temps = await service.fetchDaily(
      stationId: 'SAVW3',
      network: 'WI_COOP',
      start: DateTime(2025, 5, 1),
      end: DateTime(2025, 5, 4),
    );

    // Only the two complete rows survive; the two with a None temp are skipped.
    expect(temps.length, 2);
    expect(temps[0].date, DateTime(2025, 5, 1));
    expect(temps[0].tMax, 50.0);
    expect(temps[0].tMin, 35.0);
    expect(temps[1].tMax, 51.0);
    expect(temps[1].tMin, 43.0);
  });

  test('sends the required network and modern vars query params', () async {
    late Uri captured;
    final client = MockClient((request) async {
      captured = request.url;
      return http.Response(_sampleCsv, 200);
    });
    final service = WeatherService(client: client);

    await service.fetchDaily(
      stationId: 'SAVW3',
      network: 'WI_COOP',
      start: DateTime(2025, 5, 1),
      end: DateTime(2025, 5, 2),
    );

    expect(captured.queryParameters['station'], 'SAVW3');
    expect(captured.queryParameters['network'], 'WI_COOP');
    expect(captured.queryParameters['vars'], 'max_tmpf,min_tmpf');
    expect(captured.queryParameters.containsKey('var'), isFalse);
  });

  test('throws when the temperature columns are absent', () async {
    final client = MockClient((request) async => http.Response('station,day\n', 200));
    final service = WeatherService(client: client);

    expect(
      () => service.fetchDaily(
        stationId: 'SAVW3',
        network: 'WI_COOP',
        start: DateTime(2025, 5, 1),
        end: DateTime(2025, 5, 2),
      ),
      throwsA(isA<WeatherFetchException>()),
    );
  });
}
