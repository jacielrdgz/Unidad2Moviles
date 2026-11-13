import 'package:flutter_test/flutter_test.dart';
import 'package:offline_iot/lectura.dart';
import 'package:offline_iot/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime t(int s) => DateTime.utc(2026, 1, 1, 0, 0, s);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Last-Write-Wins: gana el updated_at más reciente', () async {
    final db = await LocalDb.open(inMemoryDatabasePath);
    final base = Lectura.simulada();
    await db.guardar(base.copyWith(nota: 'local', updatedAt: t(10), synced: false));

    // Nube más vieja: gana local y sigue pendiente de subir.
    await db.aplicarRemoto(base.copyWith(nota: 'viejo', updatedAt: t(5)));
    expect((await db.todas()).single.nota, 'local');
    expect(await db.pendientes(), hasLength(1));

    // Nube más nueva: gana la nube y queda sincronizada.
    await db.aplicarRemoto(base.copyWith(nota: 'nuevo', updatedAt: t(20)));
    expect((await db.todas()).single.nota, 'nuevo');
    expect(await db.pendientes(), isEmpty);
  });

  test('marcarSincronizado no pisa una edición hecha durante la subida', () async {
    final db = await LocalDb.open(inMemoryDatabasePath);
    final l = Lectura.simulada().copyWith(updatedAt: t(1));
    await db.guardar(l);
    await db.guardar(l.copyWith(nota: 'editada', updatedAt: t(2))); // edición concurrente
    await db.marcarSincronizado(l.id, t(1)); // confirma la versión vieja
    expect(await db.pendientes(), hasLength(1));
  });

  test('ida y vuelta a la nube conserva la marca de tiempo exacta', () {
    final l = Lectura.simulada();
    final r = Lectura.fromRemote(l.toRemote().cast<String, dynamic>());
    expect(r.updatedAt, l.updatedAt);
  });
}
