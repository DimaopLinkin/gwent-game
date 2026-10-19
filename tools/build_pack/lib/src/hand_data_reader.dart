import 'dart:convert';
import 'dart:io';

import 'package:gwent_build_pack/src/hand_data_exception.dart';
import 'package:gwent_build_pack/src/hand_tables.dart';
import 'package:gwent_content/gwent_content.dart';

/// Читает все таблицы [handTables] из папки данных [dataDir] (`docs/hand/data`): имя таблицы → разобранный JSON.
Map<String, Object?> readHandTables(Directory dataDir) => {
  for (final table in handTables) table: _readJson(File('${dataDir.path}/$table/${table}_data.json')),
};

/// Читает идентичность пакета из [file] (`docs/hand/content_pack.json`):
/// `{"pack_id": …, "pack_version": …, "min_engine_version": …}`.
PackIdentity readPackIdentity(File file) {
  final json = _readJson(file);
  if (json case {
    'pack_id': final String packId,
    'pack_version': final int packVersion,
    'min_engine_version': final int minEngineVersion,
  } when json.length == 3) {
    return PackIdentity(packId: packId, packVersion: packVersion, minEngineVersion: minEngineVersion);
  }
  throw HandDataException([
    '${file.path}: ожидались ровно поля pack_id (строка), pack_version и min_engine_version (целые)',
  ]);
}

Object? _readJson(File file) {
  try {
    return jsonDecode(file.readAsStringSync());
  } on FileSystemException catch (e) {
    throw HandDataException(['${file.path}: ${e.message}']);
  } on FormatException catch (e) {
    throw HandDataException(['${file.path}: неверный JSON, ${e.message}']);
  }
}
