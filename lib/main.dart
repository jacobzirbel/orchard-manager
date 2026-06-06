import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/degree_day_repository.dart';

void main() {
  runApp(OrchardManagerApp(repository: DegreeDayRepository()));
}

class OrchardManagerApp extends StatelessWidget {
  const OrchardManagerApp({super.key, required this.repository});

  final DegreeDayRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orchard Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
