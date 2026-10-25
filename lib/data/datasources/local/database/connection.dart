import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Opens the primary on-device SQLite database connection for AgroShift.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'agro_shift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Creates a memory-backed database for unit testing.
AppDatabase constructTestDb() {
  return AppDatabase(NativeDatabase.memory());
}
