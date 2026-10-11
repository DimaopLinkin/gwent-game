import 'package:gwent_content/src/json/canonical_json.dart';
import 'package:gwent_content/src/json/sha256_digest.dart';
import 'package:gwent_content/src/model/manifest.dart';
import 'package:gwent_content/src/pack_format.dart';
import 'package:gwent_content/src/validation/issue_sink.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Уровень «целостность» для одного файла: размер и SHA-256 байтов [bytes] совпадают с записью [file].
List<ValidationIssue> checkFileIntegrity(ManifestFile file, List<int> bytes) {
  final sink = IssueSink(ValidationLevel.integrity);
  if (bytes.length != file.size) {
    sink.add(r'$', 'size_mismatch', 'размер ${bytes.length} байт, а в манифесте ${file.size}', file: file.path);
  }
  final actual = sha256Hex(bytes);
  if (actual != file.sha256) {
    sink.add(r'$', 'hash_mismatch', 'SHA-256 $actual не совпадает с манифестом', file: file.path);
  }
  return sink.issues;
}

/// Уровень «целостность» для правил: `content_hash` манифеста равен хешу канонического JSON правил [rulesJson].
///
/// Хеш считается по смыслу, а не по байтам файла: переформатированный `pack.json` даёт тот же `content_hash`.
List<ValidationIssue> checkContentHash(Manifest manifest, Object? rulesJson) {
  final sink = IssueSink(ValidationLevel.integrity);
  try {
    final actual = contentHashOf(canonicalJsonBytes(rulesJson));
    if (actual != manifest.contentHash) {
      sink.add(r'$.content_hash', 'content_hash_mismatch', 'хеш правил $actual', file: manifestFileName);
    }
  } on CanonicalJsonException catch (e) {
    sink.add(e.path, 'not_canonicalizable', e.message);
  }
  return sink.issues;
}
