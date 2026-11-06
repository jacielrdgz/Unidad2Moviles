import 'package:flutter/material.dart';
import 'services/encrypted_json_storage.dart';

class EncryptedJsonScreen extends StatefulWidget {
  const EncryptedJsonScreen({super.key});

  @override
  State<EncryptedJsonScreen> createState() => _EncryptedJsonScreenState();
}

class _EncryptedJsonScreenState extends State<EncryptedJsonScreen> {
  final EncryptedJsonStorage _storage = EncryptedJsonStorage();
  String _result = '';

  Future<void> _save() async {
    try {
      await _storage.saveEncryptedJson('nodo.enc', {
        'nodo': 'ESP32_01',
        'sensor': 'temperatura',
        'umbral': 35.0,
      });
      setState(() => _result = 'Archivo guardado y cifrado');
    } catch (e) {
      setState(() => _result = 'Error al guardar: $e');
    }
  }

  Future<void> _read() async {
    final data = await _storage.readEncryptedJson('nodo.enc');
    setState(() => _result = data == null
        ? 'No se pudo leer (no existe o está corrupto)'
        : data.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JSON cifrado')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _save,
              child: const Text('Guardar JSON cifrado'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _read,
              child: const Text('Leer y descifrar'),
            ),
            const SizedBox(height: 16),
            Text(_result),
          ],
        ),
      ),
    );
  }
}