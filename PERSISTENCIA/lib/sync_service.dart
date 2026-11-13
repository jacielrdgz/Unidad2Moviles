import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lectura.dart';
import 'local_db.dart';

/// Sincroniza SQLite <-> Supabase automáticamente.
/// - Escucha cambios de red: al reconectar, sincroniza sin intervención del usuario.
/// - Reintento periódico por si la red "existe" pero no hay internet real.
/// - Un candado (_syncing) evita dos sincronizaciones simultáneas.
class SyncService extends ChangeNotifier {
  SyncService(this.db);

  final LocalDb db;
  SupabaseClient get _supa => Supabase.instance.client;

  bool online = false;
  bool _syncing = false;
  bool get syncing => _syncing;
  DateTime? lastSync;
  String? lastError;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _timer;

  void start() {
    _sub = Connectivity().onConnectivityChanged.listen(_onNet);
    Connectivity().checkConnectivity().then(_onNet);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => sync());
  }

  void _onNet(List<ConnectivityResult> r) {
    _redReal = r.isNotEmpty && !r.contains(ConnectivityResult.none);
    _actualizarOnline();
  }

  /// Modo avión simulado: la app se comporta como sin red aunque haya internet.
  bool modoAvion = false;
  bool _redReal = false;

  void setModoAvion(bool v) {
    modoAvion = v;
    _actualizarOnline();
  }

  void _actualizarOnline() {
    final wasOnline = online;
    online = _redReal && !modoAvion;
    notifyListeners();
    if (online && !wasOnline) sync(); // reconexión -> sincronización automática
  }

  Future<void> sync() async {
    if (_syncing || !online) return;
    _syncing = true;
    notifyListeners();
    try {
      // 1) SUBIR pendientes. upsert por id (UUID): reintentar nunca duplica.
      final pend = await db.pendientes();
      if (pend.isNotEmpty) {
        await _supa
            .from('lecturas')
            .upsert(pend.map((l) => l.toRemote()).toList(), onConflict: 'id')
            .timeout(const Duration(seconds: 10));
        for (final l in pend) {
          await db.marcarSincronizado(l.id, l.updatedAt);
        }
      }
      // 2) BAJAR cambios de la nube y resolver conflictos con Last-Write-Wins.
      // shortcut: baja la tabla completa; con miles de filas filtrar por updated_at > última sync.
      final rows = await _supa.from('lecturas').select().timeout(const Duration(seconds: 10));
      for (final r in rows) {
        await db.aplicarRemoto(Lectura.fromRemote(r));
      }
      lastSync = DateTime.now();
      lastError = null;
    } catch (e) {
      // Sin internet real / timeout: los datos siguen seguros en SQLite y se reintenta luego.
      lastError = 'Nube no disponible, se reintentará automáticamente';
      debugPrint('sync error: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
