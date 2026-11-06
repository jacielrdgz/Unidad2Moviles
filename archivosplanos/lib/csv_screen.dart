import 'dart:io';
import 'package:flutter/material.dart';
import 'services/csv_node_manager.dart';

class NodesCsvScreen extends StatefulWidget {
  const NodesCsvScreen({super.key});

  @override
  State<NodesCsvScreen> createState() => _NodesCsvScreenState();
}

class _NodesCsvScreenState extends State<NodesCsvScreen> {
  final CsvNodeManager _manager = CsvNodeManager();
  String? _path;
  bool? _valid;
  List<List<dynamic>> _nodes = [];

  final List<List<dynamic>> _sampleRows = [
    ['node_id', 'tipo', 'ubicacion', 'umbral'],
    ['ESP32_01', 'temperatura', 'Laboratorio', 35.0],
    ['ESP32_02', 'humedad', 'Bodega', 70.0],
  ];

  Future<void> _export() async {
    try {
      final path = await _manager.exportNodesToCsv(_sampleRows);
      setState(() {
        _path = path;
        _valid = null;
        _nodes = [];
      });
      _msg('Exportado en: $path');
    } catch (e) {
      _msg('Error al exportar: $e', error: true);
    }
  }

  Future<void> _import() async {
    if (_path == null) {
      _msg('Primero exporta un archivo');
      return;
    }
    try {
      final rows = await _manager.verifyAndImportCsv(_path!);
      setState(() {
        _valid = rows != null;
        _nodes = rows ?? [];
      });
    } catch (e) {
      _msg('Error al importar: $e', error: true);
    }
  }

  Future<void> _tamper() async {
    if (_path == null) {
      _msg('Primero exporta un archivo');
      return;
    }
    try {
      final f = File(_path!);
      final content = await f.readAsString();
      await f.writeAsString(content.replaceFirst('35.0', '99.0'));
      _msg('Archivo alterado manualmente');
    } catch (e) {
      _msg('Error al alterar: $e', error: true);
    }
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nodos IoT - CSV')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _export,
                  child: const Text('Exportar'),
                ),
                ElevatedButton(
                  onPressed: _import,
                  child: const Text('Importar y validar'),
                ),
                OutlinedButton(
                  onPressed: _tamper,
                  child: const Text('Alterar archivo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_path != null) SelectableText('Archivo: $_path'),
            const SizedBox(height: 12),
            if (_valid != null)
              Row(
                children: [
                  Icon(
                    _valid! ? Icons.check_circle : Icons.cancel,
                    color: _valid! ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(_valid! ? 'Integridad válida' : 'Archivo corrupto'),
                ],
              ),
            Expanded(
              child: ListView(
                children: _nodes
                    .map((r) => ListTile(title: Text(r.join(' | '))))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}