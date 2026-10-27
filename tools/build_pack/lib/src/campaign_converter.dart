import 'dart:convert';
import 'dart:io';

import 'package:gwent_build_pack/src/hand_data_exception.dart';
import 'package:gwent_content/gwent_content.dart';

/// Имя файла с главами, узлами и наградами в `docs/hand/campaign`.
const String campaignChaptersFile = 'chapters.json';

/// Имя файла с колодами противников (результат `bin/campaign_decks.dart`) в `docs/hand/campaign`.
const String campaignDecksFile = 'opponent_decks.json';

/// Исходные данные кампании из `docs/hand/campaign`: разобранный JSON глав и колод противников.
final class CampaignSource {
  /// Создаёт исходные данные кампании.
  const CampaignSource({required this.chapters, required this.decks});

  /// Содержимое `chapters.json`.
  final Object? chapters;

  /// Содержимое `opponent_decks.json`.
  final Object? decks;
}

/// Каталог кампании и тексты к нему (ключ → текст запасного языка).
final class ConvertedCampaign {
  /// Создаёт результат конвертации.
  const ConvertedCampaign({required this.catalog, required this.strings});

  /// Каталог.
  final CampaignCatalog catalog;

  /// Тексты, которые нужно добавить к строкам пакета.
  final Map<String, String> strings;
}

/// Читает данные кампании из папки [dir] (`docs/hand/campaign`) или `null`, если папки нет.
CampaignSource? readCampaignSource(Directory dir) {
  if (!dir.existsSync()) return null;
  return CampaignSource(
    chapters: _readJson(File('${dir.path}/$campaignChaptersFile')),
    decks: _readJson(File('${dir.path}/$campaignDecksFile')),
  );
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

/// Превращает данные кампании [source] в каталог пакета.
///
/// Карты в данных названы и по UUID, и по имени, чтобы файл читался человеком: имя должно совпадать с именем
/// карты в [rules] (по [cardNames]), иначе конвертация падает со [HandDataException]. Тексты узлов и глав уходят
/// в строки с ключами `campaign.*`. Правильность ссылок, копий и цепочки узлов проверяет `checkCampaign`.
ConvertedCampaign convertCampaign({
  required CampaignSource source,
  required PackRules rules,
  required StringTable cardNames,
}) => _CampaignConverter(source, rules, cardNames).convert();

final class _CampaignConverter {
  _CampaignConverter(this.source, this.rules, this.cardNames);

  final CampaignSource source;
  final PackRules rules;
  final StringTable cardNames;
  final List<String> problems = [];
  final Map<String, String> strings = {};

  ConvertedCampaign convert() {
    final root = _object(source.chapters, campaignChaptersFile);
    final starter = _object(root['starter_deck'], '$campaignChaptersFile starter_deck');
    final starterNameKey = _text('campaign.starter_deck.name', _string(starter, 'name', 'starter_deck'));
    final starterLeader = _card(starter['leader_id'], starter['leader'], 'starter_deck.leader');

    final decks = _decks();
    final chapters = <CampaignChapter>[];
    for (final json in _list(root['chapters'], 'chapters')) {
      final chapter = _object(json, 'chapters[]');
      final chapterId = _string(chapter, 'id', 'chapters[]');
      final nodes = [
        for (final node in _list(chapter['nodes'], '$chapterId nodes')) _node(_object(node, chapterId), decks),
      ];
      chapters.add(
        CampaignChapter(
          id: chapterId,
          number: _int(chapter, 'number', chapterId),
          nameKey: _text('campaign.chapter.$chapterId.name', _string(chapter, 'name', chapterId)),
          released: chapter['released'] == true,
          nodes: nodes,
        ),
      );
    }
    for (final nodeId in decks.keys) {
      if (!chapters.any((chapter) => chapter.nodes.any((node) => node.id == nodeId))) {
        problems.add('$campaignDecksFile: колода для неизвестного узла $nodeId');
      }
    }

    if (problems.isNotEmpty) throw HandDataException(problems);
    return ConvertedCampaign(
      catalog: CampaignCatalog(
        formatVersion: campaignFormatVersion,
        starterDeck: StarterDeck(nameKey: starterNameKey, leaderId: starterLeader),
        chapters: chapters,
      ),
      strings: strings,
    );
  }

  Map<String, List<CardGrant>> _decks() {
    final root = _object(source.decks, campaignDecksFile);
    final decks = _object(root['decks'], '$campaignDecksFile decks');
    return {
      for (final MapEntry(key: nodeId, value: cards) in decks.entries)
        nodeId: _grants(cards, '$campaignDecksFile $nodeId'),
    };
  }

  CampaignNode _node(Map<String, Object?> node, Map<String, List<CardGrant>> decks) {
    final nodeId = _string(node, 'id', 'node');
    final kind = NodeKind.fromKey(_string(node, 'kind', nodeId));
    if (kind == null) problems.add('$nodeId: неизвестный вид ${node['kind']}');
    final difficulty = CampaignDifficulty.fromKey(_string(node, 'difficulty', nodeId));
    if (difficulty == null) problems.add('$nodeId: неизвестный уровень ${node['difficulty']}');

    final opponent = _object(node['opponent'], '$nodeId opponent');
    final opponentNameKey = _text('campaign.node.$nodeId.opponent', _string(opponent, 'name', '$nodeId opponent'));
    final isScripted = kind == NodeKind.scripted;
    final deck = decks[nodeId];
    if (!isScripted && deck == null) problems.add('$campaignDecksFile: нет колоды для узла $nodeId');

    CampaignBonus? bonus;
    if (node['bonus'] case final Object bonusJson) {
      final bonusObject = _object(bonusJson, '$nodeId bonus');
      final condition = BonusCondition.fromKey(_string(bonusObject, 'condition', '$nodeId bonus'));
      if (condition == null) problems.add('$nodeId: неизвестное условие ${bonusObject['condition']}');
      bonus = CampaignBonus(
        condition: condition ?? BonusCondition.winTwoZero,
        reward: _grants(bonusObject['reward'], '$nodeId bonus'),
      );
    }

    return CampaignNode(
      id: nodeId,
      kind: kind ?? NodeKind.duel,
      afterId: node['after'] as String?,
      opponent: CampaignOpponent(
        nameKey: opponentNameKey,
        fractionId: isScripted ? null : _id(opponent['fraction_id'], '$nodeId fraction_id'),
        leaderId: isScripted ? null : _card(opponent['leader_id'], opponent['leader'], '$nodeId leader'),
        deck: isScripted ? const [] : deck ?? const [],
      ),
      difficulty: difficulty ?? CampaignDifficulty.easy,
      themeKey: _text('campaign.node.$nodeId.theme', _string(node, 'theme', nodeId)),
      scenario: node['scenario'] as String?,
      reward: _grants(node['reward'], '$nodeId reward'),
      bonus: bonus,
    );
  }

  List<CardGrant> _grants(Object? json, String where) => [
    for (final item in _list(json, where))
      if (_object(item, where) case final grant)
        CardGrant(cardId: _card(grant['card_id'], grant['name'], where), copies: _int(grant, 'copies', where)),
  ];

  /// UUID карты или лидера [id]; [name] должно совпадать с именем из пакета.
  String _card(Object? id, Object? name, String where) {
    if (id is! String) {
      problems.add('$where: нет card_id');
      return '';
    }
    final nameKey =
        rules.squadCardsById[id]?.nameKey ?? rules.specialCardsById[id]?.nameKey ?? rules.leaderCardsById[id]?.nameKey;
    if (nameKey == null) {
      problems.add('$where: нет карты $id');
    } else if (cardNames[nameKey] != name) {
      problems.add('$where: карта $id называется «${cardNames[nameKey]}», а в данных «$name»');
    }
    return id;
  }

  String _id(Object? value, String where) {
    if (value is String) return value;
    problems.add('$where: ожидался UUID');
    return '';
  }

  String _text(String key, String text) {
    strings[key] = text;
    return key;
  }

  String _string(Map<String, Object?> json, String key, String where) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    problems.add('$where: нет строки $key');
    return '';
  }

  int _int(Map<String, Object?> json, String key, String where) {
    final value = json[key];
    if (value is int) return value;
    problems.add('$where: нет числа $key');
    return 0;
  }

  Map<String, Object?> _object(Object? json, String where) {
    if (json is Map<String, Object?>) return json;
    problems.add('$where: ожидался объект');
    return const {};
  }

  List<Object?> _list(Object? json, String where) {
    if (json is List<Object?>) return json;
    problems.add('$where: ожидался список');
    return const [];
  }
}
