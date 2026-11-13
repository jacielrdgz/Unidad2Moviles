import 'dart:async';

import 'package:flutter/material.dart';

import 'modelos.dart';

class PaginaDashboard extends StatefulWidget {
  final Telemetria? lectura;
  final DateTime? recibida; // hora local en que llegó la lectura
  final DateTime Function() reloj;
  const PaginaDashboard(
      {super.key, required this.lectura, required this.recibida, required this.reloj});

  @override
  State<PaginaDashboard> createState() => _PaginaDashboardState();
}

class _PaginaDashboardState extends State<PaginaDashboard> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lectura;
    final ahora = widget.reloj();
    final online = estaOnline(widget.recibida, ahora);
    String v(Object? x, String sufijo) => l == null
        ? 'Sin datos'
        : x == null
            ? '—'
            : '$x$sufijo';
    final seg = widget.recibida == null
        ? 0
        : ahora.difference(widget.recibida!).inSeconds.clamp(0, 1 << 30);
    final hace = l == null ? '' : ' · hace $seg s';
    final alarma = l == null ? '—' : (l.localAlarm ? 'ENCENDIDA' : 'APAGADA');

    Widget tarjeta(String titulo, String valor, {Key? key, Color? color}) => Card(
          key: key,
          color: color,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(titulo),
              Text(valor, style: Theme.of(context).textTheme.headlineSmall),
            ]),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Chip(
          label: Text(online ? 'Online' : 'Offline'),
          backgroundColor: online ? Colors.green : Colors.grey,
        ),
        Text('Alarma local: $alarma$hace'),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            children: [
              tarjeta('Temperatura', v(l?.temperature.toStringAsFixed(1), ' °C'),
                  key: const Key('card-temp'),
                  color: (l?.critica ?? false) ? Colors.red : null),
              tarjeta('Humedad', v(l?.humidity.toStringAsFixed(0), ' %')),
              tarjeta('Calidad de aire', v(l?.airQuality, '')),
              tarjeta('Señal', v(l?.rssi, ' dBm')),
            ],
          ),
        ),
      ]),
    );
  }
}
