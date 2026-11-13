import 'dart:async';

import 'package:estacion_climatica/main.dart' show HomePage;
import 'package:estacion_climatica/modelos.dart';
import 'package:estacion_climatica/repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRepo implements EstacionRepo {
  final lecturas = StreamController<Telemetria?>.broadcast();
  final listaAlarmas = StreamController<List<Alarma>>.broadcast();
  final cambios = <(int, String)>[];
  bool falla = false;

  @override
  Stream<Telemetria?> ultimaLectura() => lecturas.stream;
  @override
  Stream<List<Alarma>> alarmas() => listaAlarmas.stream;
  @override
  Future<void> cambiarEstado(int id, String status) async {
    if (falla) throw Exception('RLS');
    cambios.add((id, status));
  }
}

Telemetria lectura(DateTime t, {double temp = 24.1}) => Telemetria(
    id: 1,
    temperature: temp,
    humidity: 37,
    airQuality: 1830,
    localAlarm: false,
    rssi: -58,
    createdAt: t);

Alarma alarma(int id, double temp, {String status = 'ACTIVE_UNACK'}) => Alarma(
    id: id,
    type: 'High Temperature Alarm',
    severity: 'CRITICAL',
    status: status,
    temperature: temp,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

Future<void> cerrar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
}

void main() {
  late FakeRepo repo;
  late DateTime ahora;
  setUp(() {
    repo = FakeRepo();
    ahora = DateTime(2026, 1, 1, 12);
  });

  Future<void> abrir(WidgetTester t) => t.pumpWidget(
      MaterialApp(home: HomePage(repo: repo, reloj: () => ahora)));

  testWidgets('sin datos: Sin datos y Offline', (t) async {
    await abrir(t);
    expect(find.text('Sin datos'), findsWidgets);
    expect(find.text('Offline'), findsOneWidget);
    repo.lecturas.add(null);
    await t.pump();
    expect(find.text('Sin datos'), findsWidgets);
    await cerrar(t);
  });

  testWidgets('lectura online, luego offline tras 16 s', (t) async {
    await abrir(t);
    repo.lecturas.add(lectura(ahora));
    await t.pump();
    for (final s in ['24.1 °C', '37 %', '1830', '-58 dBm', 'Online']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    ahora = ahora.add(const Duration(seconds: 16));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Offline'), findsOneWidget);
    await cerrar(t);
  });

  testWidgets('reloj del servidor adelantado/atrasado: Online y hace >= 0', (t) async {
    await abrir(t);
    repo.lecturas.add(lectura(ahora.subtract(const Duration(hours: 1))));
    await t.pump();
    expect(find.text('Online'), findsOneWidget);
    expect(find.textContaining('hace 0 s'), findsOneWidget);
    await cerrar(t);
    await abrir(t);
    repo.lecturas.add(lectura(ahora.add(const Duration(hours: 1))));
    await t.pump();
    expect(find.textContaining('hace -'), findsNothing);
    expect(find.text('Online'), findsOneWidget);
    await cerrar(t);
  });

  testWidgets('temperatura critica en rojo', (t) async {
    await abrir(t);
    repo.lecturas.add(lectura(ahora, temp: 31.2));
    await t.pump();
    final card = t.widget<Card>(find.byKey(const Key('card-temp')));
    expect(card.color, Colors.red);
    await cerrar(t);
  });

  testWidgets('aviso solo para alarmas nuevas', (t) async {
    await abrir(t);
    repo.listaAlarmas.add([alarma(1, 30.5)]);
    await t.pump();
    expect(find.byType(SnackBar), findsNothing);
    repo.listaAlarmas.add([alarma(2, 31.2), alarma(1, 30.5)]);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('High Temperature Alarm – 31.2 °C'), findsOneWidget);
    expect(t.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        Colors.red);
    await t.pump(const Duration(seconds: 8));
    await t.pump(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(SnackBar), findsNothing);
    repo.listaAlarmas.add([alarma(2, 33.0), alarma(1, 30.5)]);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Alarmas (2 activas)'), findsOneWidget);
    await cerrar(t);
  });

  testWidgets('reconocer y borrar llaman al repo', (t) async {
    await abrir(t);
    repo.listaAlarmas.add([alarma(7, 31)]);
    await t.pump();
    await t.tap(find.text('Alarmas (1 activas)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Reconocer'));
    await t.tap(find.text('Borrar'));
    expect(repo.cambios, [(7, 'ACTIVE_ACK'), (7, 'CLEARED_UNACK')]);
    repo.listaAlarmas.add([alarma(7, 31, status: 'CLEARED_ACK')]);
    await t.pump();
    expect(find.text('Reconocer'), findsNothing);
    expect(find.text('Borrar'), findsNothing);
    await cerrar(t);
  });

  testWidgets('error de stream muestra mensaje', (t) async {
    await abrir(t);
    repo.listaAlarmas.addError(Exception('caido'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Error de conexión'), findsOneWidget);
    await cerrar(t);
  });

  testWidgets('cambiarEstado que falla muestra mensaje', (t) async {
    repo.falla = true;
    await abrir(t);
    repo.listaAlarmas.add([alarma(7, 31)]);
    await t.pump();
    await t.tap(find.text('Alarmas (1 activas)'));
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    await t.tap(find.text('Reconocer'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('No se pudo cambiar el estado'), findsOneWidget);
    await cerrar(t);
  });
}
