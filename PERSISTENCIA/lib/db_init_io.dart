import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Android/iOS usan sqflite nativo; escritorio usa SQLite vía FFI.
void initDbFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
