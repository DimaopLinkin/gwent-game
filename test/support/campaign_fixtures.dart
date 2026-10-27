import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';

/// Каталог кампании базового пакета (его собирает `setup.sh`); тест должен вызвать
/// `TestWidgetsFlutterBinding.ensureInitialized()`.
Future<(LoadGameContent, CampaignData)> loadBaseCampaign(LoadGameContent load) async {
  final data = await LoadCampaign(load)();
  if (data == null) throw StateError('В базовом пакете нет каталога кампании');
  return (load, data);
}

/// Карта или лидер пакета по имени (для проверки наград по именам, как в `docs/spec/campaign-nodes.md`).
String idOf(CampaignData data, String name) {
  final rules = data.pack.rules;
  final matches = [
    for (final card in rules.squadCards)
      if (data.text(card.nameKey) == name) card.id,
    for (final card in rules.specialCards)
      if (data.text(card.nameKey) == name) card.id,
    for (final card in rules.leaderCards)
      if (data.text(card.nameKey) == name) card.id,
  ];
  if (matches.length != 1) throw StateError('Карта «$name»: найдено ${matches.length}');
  return matches.single;
}

/// Итог загрузки пакета для тестов, которым нужен и контент.
Future<GameContent> readyContent(LoadGameContent load) async => switch (await load()) {
  GameContentReady(:final content) => content,
  GameContentRejected(:final issues) => throw StateError(issues.join('\n')),
};
