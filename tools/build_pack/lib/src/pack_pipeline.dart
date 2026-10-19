import 'package:gwent_build_pack/src/hand_data_converter.dart';
import 'package:gwent_content/gwent_content.dart';

/// Движок, который знает все эффекты формата: сборка проверяет пакет сам по себе, без конкретного приложения.
EngineCapabilities buildEngineFor(PackIdentity identity) => EngineCapabilities(
  engineVersion: identity.minEngineVersion,
  knownEffects: {for (final effect in EffectKey.values) effect.key},
);

/// Собирает пакет из таблиц `docs/hand/data` и проверяет его тем же загрузчиком, что и приложение.
///
/// Возвращает собранный пакет, если загрузчик его принял, иначе [PackRejected] с проблемами.
Future<(BuiltContentPack, PackLoadResult)> buildAndVerify(Map<String, Object?> tables, PackIdentity identity) async {
  final converted = convertHandData(tables);
  final built = buildContentPack(
    identity: identity,
    rules: converted.rules,
    strings: {converted.strings.locale: converted.strings},
  );
  final result = await ContentPackLoader(engine: buildEngineFor(identity)).load(InMemoryContentSource(built.files));
  return (built, result);
}
