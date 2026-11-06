import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class CsvNodeManager {
  static const String _prefix = '# CHECKSUM:';

  Future<String> exportNodesToCsv(List<List<dynamic>> rows) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/iot_nodes_config.csv';

    final csvData = const ListToCsvConverter(eol: '\n').convert(rows);
    final checksum = sha256.convert(utf8.encode(csvData)).toString();

    await File(filePath).writeAsString('$_prefix$checksum\n$csvData');
    return filePath;
  }

  Future<List<List<dynamic>>?> verifyAndImportCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    if (!content.startsWith(_prefix)) return null;

    final firstBreak = content.indexOf('\n');
    if (firstBreak == -1) return null;

    final originalChecksum =
        content.substring(_prefix.length, firstBreak).trim();
    final csvBody = content.substring(firstBreak + 1);

    final recalculated = sha256.convert(utf8.encode(csvBody)).toString();
    if (originalChecksum != recalculated) return null;

    return const CsvToListConverter(eol: '\n').convert(csvBody);
  }
}