import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OrchardManagerApp());
}

class OrchardManagerApp extends StatelessWidget {
  const OrchardManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orchard Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen()
    );
  }
}