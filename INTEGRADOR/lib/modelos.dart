const double umbralTemp = 30.0;
const Duration ventanaOnline = Duration(seconds: 15);

class Telemetria {
  final int id;
  final double temperature;
  final double humidity;
  final int? airQuality;
  final bool localAlarm;
  final int? rssi;
  final DateTime createdAt;

  const Telemetria({
    required this.id,
    required this.temperature,
    required this.humidity,
    this.airQuality,
    required this.localAlarm,
    this.rssi,
    required this.createdAt,
  });

  factory Telemetria.fromMap(Map<String, dynamic> m) => Telemetria(
        id: m['id'] as int,
        temperature: (m['temperature'] as num).toDouble(),
        humidity: (m['humidity'] as num).toDouble(),
        airQuality: (m['air_quality'] as num?)?.toInt(),
        localAlarm: m['local_alarm_status'] as bool? ?? false,
        rssi: (m['rssi'] as num?)?.toInt(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  bool get critica => temperature > umbralTemp;
}

bool estaOnline(DateTime? ultima, DateTime ahora) =>
    ultima != null && ahora.difference(ultima) < ventanaOnline;

class Alarma {
  final int id;
  final String type;
  final String severity;
  final String status;
  final double temperature;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Alarma({
    required this.id,
    required this.type,
    required this.severity,
    required this.status,
    required this.temperature,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Alarma.fromMap(Map<String, dynamic> m) => Alarma(
        id: m['id'] as int,
        type: m['type'] as String,
        severity: m['severity'] as String,
        status: m['status'] as String,
        temperature: (m['temperature'] as num).toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  bool get activa => status.startsWith('ACTIVE');
  bool get reconocida => status.endsWith('_ACK') && !status.endsWith('UNACK');
}

String? estadoAlReconocer(String status) => switch (status) {
      'ACTIVE_UNACK' => 'ACTIVE_ACK',
      'CLEARED_UNACK' => 'CLEARED_ACK',
      _ => null,
    };

String? estadoAlBorrar(String status) => switch (status) {
      'ACTIVE_UNACK' => 'CLEARED_UNACK',
      'ACTIVE_ACK' => 'CLEARED_ACK',
      _ => null,
    };

List<Alarma> nuevasAlarmas(Set<int> vistas, List<Alarma> actuales) =>
    actuales.where((a) => !vistas.contains(a.id)).toList();
