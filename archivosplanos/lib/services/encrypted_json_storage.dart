import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';

class EncryptedJsonStorage {
  // Clave de 32 caracteres para AES-256
  final encrypt.Key _key =
      encrypt.Key.fromUtf8('my32lengthsupersecretkey12345678');

  Future<File> _file(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$filename');
  }

  /// Guarda el JSON cifrado con AES. El IV es aleatorio y va antes del texto cifrado.
  Future<void> saveEncryptedJson(
      String filename, Map<String, dynamic> data) async {
    final file = await _file(filename);
    final tmp = File('${file.path}.tmp');

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final encrypted = encrypter.encrypt(jsonEncode(data), iv: iv);

    // Escritura atómica: .tmp -> archivo final
    await tmp.writeAsString('${iv.base64}:${encrypted.base64}', flush: true);
    await tmp.rename(file.path);
  }

  Future<Map<String, dynamic>?> readEncryptedJson(String filename) async {
    try {
      final file = await _file(filename);
      if (!await file.exists()) return null;

      final parts = (await file.readAsString()).split(':');
      if (parts.length != 2) return null;

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final decrypted = encrypter.decrypt64(parts[1], iv: iv);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      return null; // archivo corrupto o clave incorrecta
    }
  }
}