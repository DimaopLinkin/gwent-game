import 'package:gwent_content/src/model/ability.dart';
import 'package:gwent_content/src/model/manifest.dart';
import 'package:gwent_content/src/model/pack_rules.dart';
import 'package:gwent_content/src/pack_format.dart';
import 'package:gwent_content/src/validation/engine_capabilities.dart';
import 'package:gwent_content/src/validation/issue_sink.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Уровень «совместимость» по манифесту: формат поддерживается, движок не старше нужного.
List<ValidationIssue> checkManifestCompatibility(Manifest manifest, EngineCapabilities engine) {
  final sink = IssueSink(ValidationLevel.compatibility);
  if (manifest.minEngineVersion > engine.engineVersion) {
    sink.add(
      r'$.min_engine_version',
      'engine_too_old',
      'пакету нужен движок версии ${manifest.minEngineVersion}, а в приложении ${engine.engineVersion}',
      file: manifestFileName,
    );
  }
  return sink.issues;
}

/// Проблема, если версия формата [formatVersion] не поддерживается. Проверяется до разбора манифеста:
/// у другой версии формата может быть другое устройство файлов.
ValidationIssue? checkFormatVersion(Object? formatVersion) => formatVersion == packFormatVersion
    ? null
    : ValidationIssue(
        level: ValidationLevel.compatibility,
        code: 'unsupported_format',
        path: '$manifestFileName:\$.format_version',
        message: 'формат пакета $formatVersion не поддерживается, нужен $packFormatVersion',
      );

/// Уровень «совместимость» по правилам: каждый эффект из таблиц способностей реализован движком.
List<ValidationIssue> checkEffectCompatibility(PackRules rules, EngineCapabilities engine) {
  final sink = IssueSink(ValidationLevel.compatibility);
  void visit(String table, List<Ability> abilities) {
    for (final (i, ability) in abilities.indexed) {
      if (!engine.knownEffects.contains(ability.effect.key)) {
        sink.add('\$.$table[$i].effect', 'effect_not_supported', 'движок не реализует эффект ${ability.effect.key}');
      }
    }
  }

  visit('fraction_abilities', rules.fractionAbilities);
  visit('squad_abilities', rules.squadAbilities);
  visit('special_abilities', rules.specialAbilities);
  visit('leader_abilities', rules.leaderAbilities);
  return sink.issues;
}
