import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orchard Manager'),
      ),
      body: const Center(
        child: Text(
          'Orchard Manager',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}