import 'dart:io';
import 'package:flutter/material.dart';
import 'services/preferences_storage.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final PreferencesStorage _storage = PreferencesStorage();
  double _seconds = 10;
  bool _saving = false;
  String _info = 'Aún no se ha guardado nada.';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final s = await _storage.loadSampleSeconds();
    final raw = await _storage.readRaw();
    if (!mounted) return;
    setState(() {
      _seconds = s.toDouble();
      if (raw != null) _info = 'Archivo existente:\n$raw';
    });
  }

  Future<void> _save({String? overridePath}) async {
    setState(() => _saving = true);
    try {
      final path = await _storage.save(
        sampleSeconds: _seconds.round(),
        overridePath: overridePath,
      );
      final raw = await File(path).readAsString();
      if (mounted) {
        setState(() => _info = 'Guardado en:\n$path\n\nContenido:\n$raw');
      }
      _msg('Preferencias guardadas');
    } on FileSystemException catch (e) {
      _msg('Error de escritura: ${e.message}', error: true);
    } catch (e) {
      _msg('Error inesperado: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
      appBar: AppBar(title: const Text('Preferencias (JSON)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: Text('Intervalo de muestreo: ${_seconds.round()} s'),
              subtitle: Slider(
                min: 1,
                max: 60,
                divisions: 59,
                value: _seconds,
                onChanged: (v) => setState(() => _seconds = v),
              ),
            ),
            const SizedBox(height: 12),
            if (_saving) const CircularProgressIndicator(),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(),
                  child: const Text('Guardar'),
                ),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _save(overridePath: 'Z:/no_existe/prefs.json'),
                  child: const Text('Simular fallo'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black12,
              child: SelectableText(_info),
            ),
          ],
        ),
      ),
    );
  }
}