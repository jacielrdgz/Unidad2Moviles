import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'lectura.dart';

/// Almacenamiento local SQLite: la fuente de verdad de la app (offline-first).
class LocalDb {
  LocalDb._(this._db);
  final Database _db;

  static Future<LocalDb> open([String? path]) async {
    final p = path ?? (kIsWeb ? 'lecturas.db' : join(await getDatabasesPath(), 'lecturas.db'));
    final db = await openDatabase(
      p,
      version: 1,
      singleInstance: path == null, // tests abren BD en memoria independientes
      onCreate: (db, _) => db.execute('''
        CREATE TABLE lecturas(
          id TEXT PRIMARY KEY,
          sensor TEXT NOT NULL,
          temperatura REAL NOT NULL,
          humedad REAL NOT NULL,
          es_alerta INTEGER NOT NULL,
          estado TEXT NOT NULL,
          nota TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )'''),
    );
    return LocalDb._(db);
  }

  /// Inserta o reemplaza (nueva lectura o edición local).
  Future<void> guardar(Lectura l) =>
      _db.insert('lecturas', l.toLocal(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Lectura>> todas() async =>
      (await _db.query('lecturas', orderBy: 'created_at DESC')).map(Lectura.fromLocal).toList();

  Future<List<Lectura>> pendientes() async =>
      (await _db.query('lecturas', where: 'synced = 0')).map(Lectura.fromLocal).toList();

  /// Marca como sincronizada SOLO si no fue editada mientras se subía
  /// (si cambió updated_at, sigue pendiente y se sube en la próxima vuelta).
  Future<void> marcarSincronizado(String id, DateTime updatedAt) => _db.update(
        'lecturas',
        {'synced': 1},
        where: 'id = ? AND updated_at = ?',
        whereArgs: [id, updatedAt.microsecondsSinceEpoch],
      );

  /// Last-Write-Wins al bajar de la nube: gana el updated_at más reciente.
  Future<void> aplicarRemoto(Lectura remota) => _db.transaction((txn) async {
        final rows = await txn.query('lecturas',
            columns: ['updated_at'], where: 'id = ?', whereArgs: [remota.id]);
        final r = remota.updatedAt.microsecondsSinceEpoch;
        if (rows.isEmpty || r > (rows.first['updated_at'] as int)) {
          // No existe localmente o la nube es más nueva: gana la nube.
          await txn.insert('lecturas', remota.copyWith(synced: true).toLocal(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        } else if (r == rows.first['updated_at']) {
          // Misma versión: ya está sincronizada.
          await txn.update('lecturas', {'synced': 1}, where: 'id = ?', whereArgs: [remota.id]);
        }
        // r < local: gana la versión local; queda pendiente y se subirá.
      });
}
