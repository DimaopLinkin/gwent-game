import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Файл базы пользовательских данных на устройстве (в папке документов приложения).
QueryExecutor openAppDatabaseConnection() => driftDatabase(name: 'gwent');
