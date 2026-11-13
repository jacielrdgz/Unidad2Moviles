import 'dart:math';

import 'package:uuid/uuid.dart';

/// Una lectura del sensor IoT (simulado).
class Lectura {
  final String id;
  final String sensor;
  final double temperatura;
  final double humedad;
  final bool esAlerta;
  final String estado; // 'pendiente' | 'atendida'
  final String nota;
  final DateTime createdAt; // UTC
  final DateTime updatedAt; // UTC, base de Last-Write-Wins
  final bool synced; // solo local: ¿ya está en la nube?

  const Lectura({
    required this.id,
    required this.sensor,
    required this.temperatura,
    required this.humedad,
    required this.esAlerta,
    required this.estado,
    required this.nota,
    required this.createdAt,
    required this.updatedAt,
    required this.synced,
  });

  static final _rnd = Random();

  /// Simula una lectura del sensor. Temperatura > 35 °C genera alerta.
  factory Lectura.simulada() {
    final now = DateTime.now().toUtc();
    final temp = 15 + _rnd.nextDouble() * 30;
    return Lectura(
      id: const Uuid().v4(),
      sensor: 'ESP32-SIM-01',
      temperatura: double.parse(temp.toStringAsFixed(1)),
      humedad: double.parse((20 + _rnd.nextDouble() * 70).toStringAsFixed(1)),
      esAlerta: temp > 35,
      estado: 'pendiente',
      nota: '',
      createdAt: now,
      updatedAt: now,
      synced: false,
    );
  }

  Lectura copyWith({String? estado, String? nota, DateTime? updatedAt, bool? synced}) => Lectura(
        id: id,
        sensor: sensor,
        temperatura: temperatura,
        humedad: humedad,
        esAlerta: esAlerta,
        estado: estado ?? this.estado,
        nota: nota ?? this.nota,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        synced: synced ?? this.synced,
      );

  // SQLite: fechas en microsegundos para no perder precisión frente a Postgres.
  Map<String, Object?> toLocal() => {
        'id': id,
        'sensor': sensor,
        'temperatura': temperatura,
        'humedad': humedad,
        'es_alerta': esAlerta ? 1 : 0,
        'estado': estado,
        'nota': nota,
        'created_at': createdAt.microsecondsSinceEpoch,
        'updated_at': updatedAt.microsecondsSinceEpoch,
        'synced': synced ? 1 : 0,
      };

  factory Lectura.fromLocal(Map<String, Object?> m) => Lectura(
        id: m['id'] as String,
        sensor: m['sensor'] as String,
        temperatura: (m['temperatura'] as num).toDouble(),
        humedad: (m['humedad'] as num).toDouble(),
        esAlerta: m['es_alerta'] == 1,
        estado: m['estado'] as String,
        nota: m['nota'] as String,
        createdAt: DateTime.fromMicrosecondsSinceEpoch(m['created_at'] as int, isUtc: true),
        updatedAt: DateTime.fromMicrosecondsSinceEpoch(m['updated_at'] as int, isUtc: true),
        synced: m['synced'] == 1,
      );

  // Supabase: no se envía 'synced' (es solo local).
  Map<String, Object?> toRemote() => {
        'id': id,
        'sensor': sensor,
        'temperatura': temperatura,
        'humedad': humedad,
        'es_alerta': esAlerta,
        'estado': estado,
        'nota': nota,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Lectura.fromRemote(Map<String, dynamic> m) => Lectura(
        id: m['id'] as String,
        sensor: m['sensor'] as String,
        temperatura: (m['temperatura'] as num).toDouble(),
        humedad: (m['humedad'] as num).toDouble(),
        esAlerta: m['es_alerta'] as bool,
        estado: m['estado'] as String,
        nota: m['nota'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(m['updated_at'] as String).toUtc(),
        synced: true,
      );
}
