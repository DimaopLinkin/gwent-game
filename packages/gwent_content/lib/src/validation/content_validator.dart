import 'package:gwent_content/src/codec/decode_result.dart';
import 'package:gwent_content/src/codec/rules_codec.dart';
import 'package:gwent_content/src/codec/strings_codec.dart';
import 'package:gwent_content/src/model/pack_rules.dart';
import 'package:gwent_content/src/model/string_table.dart';
import 'package:gwent_content/src/pack_format.dart';
import 'package:gwent_content/src/validation/invariant_check.dart';
import 'package:gwent_content/src/validation/reference_check.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Правила и строки, прошедшие уровни «схема», «ссылки» и «инварианты».
final class ValidatedContent {
  /// Создаёт проверенное содержимое.
  ValidatedContent({required this.rules, required Map<String, StringTable> strings})
    : strings = Map.unmodifiable(strings);

  /// Таблицы правил.
  final PackRules rules;

  /// Строки по языку.
  final Map<String, StringTable> strings;
}

/// Проверяет уровни «схема», «ссылки» и «инварианты» для разобранного JSON правил [rulesJson] и строк
/// [stringsJson] (язык → JSON файла строк). Этот же код запускают CI, сборка пакета и приложение.
///
/// Уровни идут по порядку; следующий запускается, только если предыдущий прошёл без проблем, иначе вторичные
/// ошибки заслонили бы причину. Совместимость с движком и целостность файлов проверяет загрузчик.
DecodeResult<ValidatedContent> validateContent(Object? rulesJson, Map<String, Object?> stringsJson) {
  final issues = <ValidationIssue>[];
  final rulesResult = decodeRules(rulesJson);
  if (rulesResult case DecodeFailed(issues: final found)) issues.addAll(found);

  final strings = <String, StringTable>{};
  for (final MapEntry(key: locale, value: json) in stringsJson.entries) {
    switch (decodeStrings(locale, json)) {
      case Decoded(:final value):
        strings[locale] = value;
      case DecodeFailed(issues: final found):
        issues.addAll(found);
    }
  }
  if (!stringsJson.containsKey(fallbackLocale)) {
    issues.add(
      ValidationIssue(
        level: ValidationLevel.schema,
        code: 'missing_fallback_locale',
        path: stringsFileName(fallbackLocale),
        message: 'нет строк запасного языка $fallbackLocale',
      ),
    );
  }

  if (issues.isNotEmpty) return DecodeFailed(issues);
  final rules = (rulesResult as Decoded<PackRules>).value;

  final referenceIssues = checkReferences(rules, strings);
  if (referenceIssues.isNotEmpty) return DecodeFailed(referenceIssues);

  final invariantIssues = checkInvariants(rules, strings[fallbackLocale]!);
  if (invariantIssues.isNotEmpty) return DecodeFailed(invariantIssues);

  return Decoded(ValidatedContent(rules: rules, strings: strings));
}
