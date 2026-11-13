import 'package:estacion_climatica/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _tel({num t = 24.1}) => {
      'id': 1,
      'temperature': t,
      'humidity': 37,
      'air_quality': 1830,
      'local_alarm_status': false,
      'rssi': -58,
      'created_at': '2026-11-12T10:00:00Z',
    };

Alarma _alarma(int id, double temp) => Alarma.fromMap({
      'id': id,
      'type': 'TEMP',
      'severity': 'CRITICAL',
      'status': 'ACTIVE_UNACK',
      'temperature': temp,
      'created_at': '2026-11-12T10:00:00Z',
      'updated_at': '2026-11-12T10:00:00Z',
    });

void main() {
  test('Telemetria.fromMap convierte int a double y lee air_quality', () {
    final t = Telemetria.fromMap(_tel());
    expect(t.humidity, 37.0);
    expect(t.airQuality, 1830);
    expect(t.rssi, -58);
    expect(t.localAlarm, false);
  });

  test('Telemetria.fromMap sin air_quality ni rssi', () {
    final m = _tel()..remove('air_quality')..remove('rssi');
    final t = Telemetria.fromMap(m);
    expect(t.airQuality, isNull);
    expect(t.rssi, isNull);
  });

  test('critica solo por encima del umbral', () {
    expect(Telemetria.fromMap(_tel(t: 30.0)).critica, false);
    expect(Telemetria.fromMap(_tel(t: 30.1)).critica, true);
  });

  test('estaOnline', () {
    final t = DateTime.utc(2026, 11, 12, 10);
    expect(estaOnline(null, t), false);
    expect(estaOnline(t.subtract(const Duration(seconds: 14)), t), true);
    expect(estaOnline(t.subtract(const Duration(seconds: 15)), t), false);
  });

  test('estadoAlReconocer', () {
    expect(estadoAlReconocer('ACTIVE_UNACK'), 'ACTIVE_ACK');
    expect(estadoAlReconocer('CLEARED_UNACK'), 'CLEARED_ACK');
    expect(estadoAlReconocer('ACTIVE_ACK'), isNull);
  });

  test('estadoAlBorrar', () {
    expect(estadoAlBorrar('ACTIVE_UNACK'), 'CLEARED_UNACK');
    expect(estadoAlBorrar('ACTIVE_ACK'), 'CLEARED_ACK');
    expect(estadoAlBorrar('CLEARED_ACK'), isNull);
  });

  test('nuevasAlarmas', () {
    final a1 = _alarma(1, 31), a2 = _alarma(2, 32);
    expect(nuevasAlarmas({1}, [a1, a2]).map((a) => a.id), [2]);
    expect(nuevasAlarmas({1, 2}, [_alarma(1, 40), a2]), isEmpty);
  });

  test('Alarma activa/reconocida', () {
    final a = _alarma(1, 31);
    expect(a.activa, true);
    expect(a.reconocida, false);
  });
}
