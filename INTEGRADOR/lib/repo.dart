import 'package:supabase_flutter/supabase_flutter.dart';

import 'modelos.dart';

abstract class EstacionRepo {
  Stream<Telemetria?> ultimaLectura();
  Stream<List<Alarma>> alarmas();
  Future<void> cambiarEstado(int id, String status);
}

class SupabaseRepo implements EstacionRepo {
  final _db = Supabase.instance.client;

  @override
  Stream<Telemetria?> ultimaLectura() => _db
      .from('telemetria')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(1)
      .map((rows) => rows.isEmpty ? null : Telemetria.fromMap(rows.first));

  @override
  Stream<List<Alarma>> alarmas() => _db
      .from('alarmas')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Alarma.fromMap).toList());

  @override
  Future<void> cambiarEstado(int id, String status) {
    final ahora = DateTime.now().toUtc().toIso8601String();
    return _db.from('alarmas').update({
      'status': status,
      if (status.endsWith('_ACK')) 'ack_at': ahora,
      if (status.startsWith('CLEARED_')) 'cleared_at': ahora,
    }).eq('id', id);
  }
}
