import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/sensor_reading.dart';

class HistoricalAlertsScreen extends StatefulWidget {
  const HistoricalAlertsScreen({super.key});

  @override
  State<HistoricalAlertsScreen> createState() => _HistoricalAlertsScreenState();
}

class _HistoricalAlertsScreenState extends State<HistoricalAlertsScreen> {
  late Future<List<SensorReading>> _readingsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _readingsFuture = DatabaseHelper.instance.getReadingsByType('temperature');
    });
  }

  Future<void> _addTestReading() async {
    await DatabaseHelper.instance.insertReading(SensorReading(
      sensorType: 'temperature',
      value: 30 + (DateTime.now().second % 15).toDouble(),
      timestamp: DateTime.now().toIso8601String(),
      ubicacionNodo: 'Sector A',
    ));
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Alertas Temp.')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTestReading,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<SensorReading>>(
        future: _readingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos locales\n${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay registros guardados.'));
          }

          final readings = snapshot.data!;
          return ListView.builder(
            itemCount: readings.length,
            itemBuilder: (context, index) {
              final item = readings[index];
              return ListTile(
                leading: Icon(
                  Icons.warning,
                  color: item.value > 35.0 ? Colors.red : Colors.orange,
                ),
                title: Text('${item.sensorType.toUpperCase()}: ${item.value} °C'),
                subtitle: Text('${item.ubicacionNodo} • ${item.timestamp}'),
              );
            },
          );
        },
      ),
    );
  }
}