import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sensor_reading.dart';
import '../models/alert.dart';

/// Gestor de la base de datos local (Smart-Environment IoT).
/// Usa el patrón Singleton: una sola instancia y una sola conexión.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('iot_local.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE nodes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        location TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sensorType TEXT NOT NULL,
        value REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        node_id TEXT NOT NULL,
        message TEXT NOT NULL,
        value REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (node_id) REFERENCES nodes(id) ON DELETE CASCADE
      )
    ''');
  }

  // ---------- NODOS ----------
  Future<int> insertNode(String id, String name, String location) async {
    final db = await instance.database;
    return await db.insert(
      'nodes',
      {'id': id, 'name': name, 'location': location},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- LECTURAS ----------
  Future<int> insertReading(SensorReading reading) async {
    final db = await instance.database;
    return await db.insert('readings', reading.toMap());
  }

  // Transacción ACID: se guardan todas o ninguna
  Future<void> insertBatchReadings(List<SensorReading> readings) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in readings) {
        batch.insert('readings', r.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<SensorReading>> getReadingsByType(String type) async {
    final db = await instance.database;
    final result = await db.query(
      'readings',
      where: 'sensorType = ?', // parametrizado: evita SQL Injection
      whereArgs: [type],
      orderBy: 'id DESC',
    );
    return result.map((m) => SensorReading.fromMap(m)).toList();
  }

  // ---------- ALERTAS ----------
  Future<int> insertAlert(Alert alert) async {
    final db = await instance.database;
    return await db.insert('alerts', alert.toMap());
  }

  Future<List<Alert>> getAlertsByNode(String nodeId) async {
    final db = await instance.database;
    final result = await db.query(
      'alerts',
      where: 'node_id = ?',
      whereArgs: [nodeId],
      orderBy: 'id DESC',
    );
    return result.map((m) => Alert.fromMap(m)).toList();
  }
}