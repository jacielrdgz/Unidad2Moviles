import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PreferencesStorage {
  Future<String> defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}user_preferences.json';
  }

  /// Escritura asíncrona: no bloquea el hilo principal (UI).
  Future<String> save({
    required int sampleSeconds,
    String? overridePath,
  }) async {
    final path = overridePath ?? await defaultPath();
    final json = jsonEncode({'sampleSeconds': sampleSeconds});

    final tmp = File('$path.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(path);
    return path;
  }

  Future<String?> readRaw() async {
    final file = File(await defaultPath());
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<int> loadSampleSeconds() async {
    try {
      final raw = await readRaw();
      if (raw == null) return 10;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (map['sampleSeconds'] as num).toInt();
    } catch (_) {
      return 10;
    }
  }
}