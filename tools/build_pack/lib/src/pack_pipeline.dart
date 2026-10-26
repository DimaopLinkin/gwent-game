import 'package:gwent_build_pack/src/campaign_converter.dart';
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
///
/// Данные кампании [campaign] необязательны: без них в пакете нет каталога кампании.
Future<(BuiltContentPack, PackLoadResult)> buildAndVerify(
  Map<String, Object?> tables,
  PackIdentity identity, {
  CampaignSource? campaign,
}) async {
  final converted = convertHandData(tables);
  final convertedCampaign = campaign == null
      ? null
      : convertCampaign(source: campaign, rules: converted.rules, cardNames: converted.strings);
  final strings = StringTable(
    locale: converted.strings.locale,
    entries: {...converted.strings.entries, ...?convertedCampaign?.strings},
  );
  final built = buildContentPack(
    identity: identity,
    rules: converted.rules,
    strings: {strings.locale: strings},
    campaign: convertedCampaign?.catalog,
  );
  final result = await ContentPackLoader(engine: buildEngineFor(identity)).load(InMemoryContentSource(built.files));
  return (built, result);
}
