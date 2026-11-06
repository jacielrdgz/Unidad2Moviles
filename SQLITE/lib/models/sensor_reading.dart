class SensorReading {
  final int? id;
  final String sensorType; // 'temperature', 'humidity'
  final double value;
  final String timestamp;
  final String ubicacionNodo;

  SensorReading({
    this.id,
    required this.sensorType,
    required this.value,
    required this.timestamp,
    this.ubicacionNodo = 'Sin ubicación',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sensorType': sensorType,
        'value': value,
        'timestamp': timestamp,
        //'ubicacion_nodo': ubicacionNodo,
      };

  factory SensorReading.fromMap(Map<String, dynamic> map) => SensorReading(
        id: map['id'] as int?,
        sensorType: map['sensorType'] as String,
        value: (map['value'] as num).toDouble(),
        timestamp: map['timestamp'] as String,
        ubicacionNodo: (map['ubicacion_nodo'] as String?) ?? 'Sin ubicación',
      );
}