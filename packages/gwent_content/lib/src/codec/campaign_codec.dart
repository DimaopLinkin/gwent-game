import 'package:gwent_content/src/codec/decode_result.dart';
import 'package:gwent_content/src/codec/json_reader.dart';
import 'package:gwent_content/src/model/campaign.dart';
import 'package:gwent_content/src/pack_format.dart';

final RegExp _id = RegExp(r'^[a-z0-9][a-z0-9-]*$');

/// Разбирает `campaign.json`: типы, обязательные поля и значения перечислений. Ссылки, награды и строки
/// проверяет `checkCampaign`.
DecodeResult<CampaignCatalog> decodeCampaign(Object? json) {
  final r = JsonReader(campaignFileName);
  final root = r.object(json, r'$', required: const {'format_version', 'starter_deck', 'chapters'});

  final starter = r.object(root['starter_deck'], r'$.starter_deck', required: const {'name_key', 'leader_id'});
  final starterDeck = StarterDeck(
    nameKey: r.string(starter, 'name_key', r'$.starter_deck'),
    leaderId: r.uuid(starter, 'leader_id', r'$.starter_deck'),
  );

  final chapters = <CampaignChapter>[];
  final items = root.containsKey('chapters') ? r.list(root['chapters'], r'$.chapters') : const <Object?>[];
  for (var i = 0; i < items.length; i++) {
    final path = '\$.chapters[$i]';
    final chapter = r.object(items[i], path, required: const {'id', 'number', 'name_key', 'released', 'nodes'});
    final nodes = <CampaignNode>[];
    final nodeItems = chapter.containsKey('nodes') ? r.list(chapter['nodes'], '$path.nodes') : const <Object?>[];
    for (var j = 0; j < nodeItems.length; j++) {
      nodes.add(_node(r, nodeItems[j], '$path.nodes[$j]'));
    }
    chapters.add(
      CampaignChapter(
        id: r.matching(chapter, 'id', path, _id, 'идентификатор из [a-z0-9-]'),
        number: r.integer(chapter, 'number', path, min: 1),
        nameKey: r.string(chapter, 'name_key', path),
        released: r.boolean(chapter, 'released', path),
        nodes: nodes,
      ),
    );
  }

  final catalog = CampaignCatalog(
    formatVersion: r.integer(root, 'format_version', r'$', min: 1),
    starterDeck: starterDeck,
    chapters: chapters,
  );
  return r.issues.isEmpty ? Decoded(catalog) : DecodeFailed(r.issues);
}

CampaignNode _node(JsonReader r, Object? json, String path) {
  final node = r.object(
    json,
    path,
    required: const {'id', 'kind', 'after', 'opponent', 'difficulty', 'theme_key', 'reward'},
    optional: const {'scenario', 'bonus'},
  );
  final kindKey = r.string(node, 'kind', path);
  final kind = NodeKind.fromKey(kindKey);
  if (kind == null && kindKey.isNotEmpty) r.error('$path.kind', 'unknown_value', 'неизвестный вид узла $kindKey');
  final difficultyKey = r.string(node, 'difficulty', path);
  final difficulty = CampaignDifficulty.fromKey(difficultyKey);
  if (difficulty == null && difficultyKey.isNotEmpty) {
    r.error('$path.difficulty', 'unknown_value', 'неизвестный уровень $difficultyKey');
  }

  final opponentPath = '$path.opponent';
  final opponent = r.object(
    node['opponent'],
    opponentPath,
    required: const {'name_key'},
    optional: const {'fraction_id', 'leader_id', 'deck'},
  );

  final bonusJson = node['bonus'];
  CampaignBonus? bonus;
  if (bonusJson != null) {
    final bonusPath = '$path.bonus';
    final bonusObject = r.object(bonusJson, bonusPath, required: const {'condition', 'reward'});
    final conditionKey = r.string(bonusObject, 'condition', bonusPath);
    final condition = BonusCondition.fromKey(conditionKey);
    if (condition == null && conditionKey.isNotEmpty) {
      r.error('$bonusPath.condition', 'unknown_value', 'неизвестное условие $conditionKey');
    }
    bonus = CampaignBonus(
      condition: condition ?? BonusCondition.winTwoZero,
      reward: _grants(r, bonusObject['reward'], '$bonusPath.reward'),
    );
  }

  return CampaignNode(
    id: r.matching(node, 'id', path, _id, 'идентификатор из [a-z0-9-]'),
    kind: kind ?? NodeKind.duel,
    afterId: r.nullableString(node, 'after', path),
    opponent: CampaignOpponent(
      nameKey: r.string(opponent, 'name_key', opponentPath),
      fractionId: r.nullableUuid(opponent, 'fraction_id', opponentPath),
      leaderId: r.nullableUuid(opponent, 'leader_id', opponentPath),
      deck: opponent.containsKey('deck') ? _grants(r, opponent['deck'], '$opponentPath.deck') : const [],
    ),
    difficulty: difficulty ?? CampaignDifficulty.easy,
    themeKey: r.string(node, 'theme_key', path),
    scenario: r.nullableString(node, 'scenario', path),
    reward: _grants(r, node['reward'], '$path.reward'),
    bonus: bonus,
  );
}

List<CardGrant> _grants(JsonReader r, Object? json, String path) {
  final grants = <CardGrant>[];
  final items = r.list(json, path);
  for (var i = 0; i < items.length; i++) {
    final at = '$path[$i]';
    final grant = r.object(items[i], at, required: const {'card_id', 'copies'});
    grants.add(CardGrant(cardId: r.uuid(grant, 'card_id', at), copies: r.integer(grant, 'copies', at, min: 1)));
  }
  return grants;
}

/// Записывает каталог в JSON, который [decodeCampaign] читает обратно без потерь.
Map<String, Object?> encodeCampaign(CampaignCatalog catalog) => {
  'format_version': catalog.formatVersion,
  'starter_deck': {'name_key': catalog.starterDeck.nameKey, 'leader_id': catalog.starterDeck.leaderId},
  'chapters': [
    for (final chapter in catalog.chapters)
      {
        'id': chapter.id,
        'number': chapter.number,
        'name_key': chapter.nameKey,
        'released': chapter.released,
        'nodes': [for (final node in chapter.nodes) _encodeNode(node)],
      },
  ],
};

Map<String, Object?> _encodeNode(CampaignNode node) => {
  'id': node.id,
  'kind': node.kind.key,
  'after': node.afterId,
  'opponent': {
    'name_key': node.opponent.nameKey,
    'fraction_id': ?node.opponent.fractionId,
    'leader_id': ?node.opponent.leaderId,
    if (node.opponent.deck.isNotEmpty) 'deck': _encodeGrants(node.opponent.deck),
  },
  'difficulty': node.difficulty.key,
  'theme_key': node.themeKey,
  'scenario': ?node.scenario,
  'reward': _encodeGrants(node.reward),
  if (node.bonus case final bonus?) 'bonus': {'condition': bonus.condition.key, 'reward': _encodeGrants(bonus.reward)},
};

List<Map<String, Object?>> _encodeGrants(List<CardGrant> grants) => [
  for (final grant in grants) {'card_id': grant.cardId, 'copies': grant.copies},
];
