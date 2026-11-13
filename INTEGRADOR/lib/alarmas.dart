import 'package:flutter/material.dart';

import 'modelos.dart';

String _hora(DateTime t) {
  final l = t.toLocal();
  String d(int n) => n.toString().padLeft(2, '0');
  return '${d(l.hour)}:${d(l.minute)}:${d(l.second)}';
}

class PaginaAlarmas extends StatelessWidget {
  final List<Alarma> alarmas;
  final void Function(int id, String status) onCambio;
  const PaginaAlarmas({super.key, required this.alarmas, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    if (alarmas.isEmpty) return const Center(child: Text('Sin alarmas'));
    return ListView(
      children: [
        for (final a in alarmas)
          ListTile(
            title: Text('${a.type} – ${a.temperature.toStringAsFixed(1)} °C'),
            subtitle: Text('${a.severity} · ${a.status} · ${_hora(a.createdAt)}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (estadoAlReconocer(a.status) case final s?)
                TextButton(
                    onPressed: () => onCambio(a.id, s),
                    child: const Text('Reconocer')),
              if (estadoAlBorrar(a.status) case final s?)
                TextButton(
                    onPressed: () => onCambio(a.id, s),
                    child: const Text('Borrar')),
            ]),
          ),
      ],
    );
  }
}
