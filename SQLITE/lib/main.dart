import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/database_helper.dart';
import 'models/sensor_reading.dart';
import 'models/alert.dart';
import 'screens/historical_alerts_screen.dart';

Future<void> seedData() async {
  final db = DatabaseHelper.instance;

  await db.insertNode('ESP32_01', 'Nodo Invernadero', 'Sector A');

  await db.insertBatchReadings([
    SensorReading(sensorType: 'temperature', value: 28.5, timestamp: DateTime.now().toIso8601String()),
    SensorReading(sensorType: 'temperature', value: 36.2, timestamp: DateTime.now().toIso8601String()),
    SensorReading(sensorType: 'temperature', value: 41.0, timestamp: DateTime.now().toIso8601String()),
    SensorReading(sensorType: 'humidity', value: 65.0, timestamp: DateTime.now().toIso8601String()),
  ]);

  await db.insertAlert(Alert(
    nodeId: 'ESP32_01',
    message: 'Temperatura sobre el umbral',
    value: 41.0,
    timestamp: DateTime.now().toIso8601String(),
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización para escritorio (Windows/Linux/macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await seedData(); // la comentaremos después de la primera ejecución
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Environment',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HistoricalAlertsScreen(),
    );
  }
}