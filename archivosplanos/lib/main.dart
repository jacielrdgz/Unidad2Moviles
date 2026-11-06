import 'package:flutter/material.dart';
import 'csv_screen.dart';
import 'encrypted_json_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modulo 1',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Módulo 1 - Archivos planos')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _open(context, EncryptedJsonScreen()),
              child: const Text('Ejemplo: JSON cifrado (AES)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _open(context, NodesCsvScreen()),
              child: const Text('Práctica 1: CSV + SHA-256'),
            ),
          ],
        ),
      ),
    );
  }
}