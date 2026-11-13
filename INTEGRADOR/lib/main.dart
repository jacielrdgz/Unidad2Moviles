import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alarmas.dart';
import 'config.dart';
import 'dashboard.dart';
import 'modelos.dart';
import 'repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(MaterialApp(
    title: 'Estación climática',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: HomePage(repo: SupabaseRepo()),
  ));
}

class HomePage extends StatefulWidget {
  final EstacionRepo repo;
  final DateTime Function() reloj;
  const HomePage({super.key, required this.repo, this.reloj = DateTime.now});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _subs = <StreamSubscription>[];
  final _vistas = <int>{};
  Telemetria? _lectura;
  DateTime? _recibida; // hora local de llegada: evita depender del reloj del visor vs servidor
  List<Alarma> _alarmas = [];
  bool _primera = true;

  @override
  void initState() {
    super.initState();
    _subs.add(widget.repo.ultimaLectura().listen(
        (l) => setState(() {
              if (l == null || l.id != _lectura?.id) _recibida = l == null ? null : widget.reloj();
              _lectura = l;
            }),
        onError: (Object e) => _error('Error de conexión: $e')));
    _subs.add(widget.repo.alarmas().listen(_onAlarmas,
        onError: (Object e) => _error('Error de conexión: $e')));
  }

  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _cambiar(int id, String status) async {
    try {
      await widget.repo.cambiarEstado(id, status);
    } catch (e) {
      _error('No se pudo cambiar el estado: $e');
    }
  }

  void _onAlarmas(List<Alarma> lista) {
    // La primera emisión solo llena `vistas`: no avisa de alarmas ya existentes.
    final nuevas = _primera ? <Alarma>[] : nuevasAlarmas(_vistas, lista);
    _primera = false;
    _vistas.addAll(lista.map((a) => a.id));
    setState(() => _alarmas = lista);
    if (nuevas.isNotEmpty) {
      final a = nuevas.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text('${a.type} – ${a.temperature.toStringAsFixed(1)} °C')));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activas = _alarmas.where((a) => a.activa).length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estación climática'),
          bottom: TabBar(tabs: [
            const Tab(text: 'Dashboard'),
            Tab(text: 'Alarmas ($activas activas)'),
          ]),
        ),
        body: TabBarView(children: [
          PaginaDashboard(
              lectura: _lectura, recibida: _recibida, reloj: widget.reloj),
          PaginaAlarmas(alarmas: _alarmas, onCambio: _cambiar),
        ]),
      ),
    );
  }
}
