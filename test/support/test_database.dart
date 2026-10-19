import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gwent/src/core/database/app_database.dart';

/// Пустая база в памяти. Потоки закрываются сразу, поэтому тесты виджетов не ждут таймеров Drift.
AppDatabase openTestDatabase() =>
    AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
