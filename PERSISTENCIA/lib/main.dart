import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'db_init_io.dart' if (dart.library.js_interop) 'db_init_web.dart';
import 'lectura.dart';
import 'local_db.dart';
import 'sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDbFactory();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  final db = await LocalDb.open();
  final sync = SyncService(db)..start();
  runApp(MaterialApp(
    title: 'IoT Offline-First',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: HomePage(db: db, sync: sync),
  ));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.db, required this.sync});
  final LocalDb db;
  final SyncService sync;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Lectura> _lecturas = [];

  @override
  void initState() {
    super.initState();
    widget.sync.addListener(_cargar); // refresca la lista tras cada sync / cambio de red
    _cargar();
  }

  @override
  void dispose() {
    widget.sync.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    final l = await widget.db.todas();
    if (mounted) setState(() => _lecturas = l);
  }

  /// Siempre se guarda primero en SQLite; la nube es secundaria.
  Future<void> _generar(int n) async {
    for (var i = 0; i < n; i++) {
      await widget.db.guardar(Lectura.simulada());
    }
    await _cargar();
    unawaited(widget.sync.sync());
  }

  Future<void> _editar(Lectura l) async {
    var estado = l.estado;
    final nota = TextEditingController(text: l.nota);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Editar alerta'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(value: 'atendida', child: Text('Atendida')),
              ],
              onChanged: (v) => setD(() => estado = v!),
            ),
            TextField(controller: nota, decoration: const InputDecoration(labelText: 'Nota')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true) {
      // Nueva marca de tiempo: esta edición gana a cualquier versión más vieja (LWW).
      await widget.db.guardar(l.copyWith(
          estado: estado, nota: nota.text, updatedAt: DateTime.now().toUtc(), synced: false));
      await _cargar();
      unawaited(widget.sync.sync());
    }
    nota.dispose();
  }

  String _hora(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sync;
    final pendientes = _lecturas.where((l) => !l.synced).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor IoT · Offline-First'),
        actions: [
          IconButton(
            tooltip: s.modoAvion ? 'Desactivar modo avión simulado' : 'Simular modo avión',
            isSelected: s.modoAvion,
            icon: const Icon(Icons.airplanemode_inactive),
            selectedIcon: const Icon(Icons.airplanemode_active, color: Colors.orange),
            onPressed: () => s.setModoAvion(!s.modoAvion),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: Icon(s.online ? Icons.wifi : Icons.wifi_off,
                  color: s.online ? Colors.green : Colors.red, size: 18),
              label: Text(s.online ? 'En línea' : (s.modoAvion ? 'Modo avión' : 'Sin conexión')),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            [
              'Total: ${_lecturas.length}  ·  Pendientes de subir: $pendientes',
              if (s.syncing) 'Sincronizando…',
              if (s.lastSync != null) 'Última sync: ${_hora(s.lastSync!)}',
              if (!s.online) 'Guardando localmente en SQLite',
              if (s.online && s.lastError != null) s.lastError!,
            ].join('\n'),
          ),
        ),
        Expanded(
          child: _lecturas.isEmpty
              ? const Center(child: Text('Sin lecturas. Genera una con el botón.'))
              : ListView.separated(
                  itemCount: _lecturas.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final l = _lecturas[i];
                    return ListTile(
                      leading: Icon(l.esAlerta ? Icons.warning_amber : Icons.sensors,
                          color: l.esAlerta ? Colors.orange : null),
                      title: Text('${l.temperatura} °C  ·  ${l.humedad} %'),
                      subtitle: Text('${_hora(l.createdAt)} · ${l.estado}'
                          '${l.nota.isEmpty ? '' : ' · ${l.nota}'}'),
                      trailing: Icon(l.synced ? Icons.cloud_done : Icons.cloud_upload,
                          color: l.synced ? Colors.green : Colors.grey),
                      onTap: () => _editar(l),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          heroTag: 'cinco',
          onPressed: () => _generar(5),
          tooltip: 'Generar 5 lecturas',
          child: const Text('x5'),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'una',
          onPressed: () => _generar(1),
          icon: const Icon(Icons.add),
          label: const Text('Generar lectura'),
        ),
      ]),
    );
  }
}
