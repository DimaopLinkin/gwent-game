import 'package:gwent_content/src/model/campaign.dart';
import 'package:gwent_content/src/model/pack_rules.dart';
import 'package:gwent_content/src/model/string_table.dart';
import 'package:gwent_content/src/pack_format.dart';
import 'package:gwent_content/src/validation/issue_sink.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Проверяет каталог кампании [catalog] по правилам пакета [rules] и строкам [strings].
///
/// Сначала «ссылки»: формат каталога, уникальные идентификаторы, карты и лидеры существуют, у каждого ключа
/// есть текст на каждом языке и каждый текст кампании кому-то нужен. Затем, только если ссылки целы,
/// «инварианты» (ADR 0033): цепочка узлов, виды узлов, выданные копии каждой карты ровно равны `count`,
/// каждый лидер выдан один раз, колоды противников собираются по правилам.
List<ValidationIssue> checkCampaign(CampaignCatalog catalog, PackRules rules, Map<String, StringTable> strings) {
  final references = IssueSink(ValidationLevel.references);
  _checkReferences(catalog, rules, strings, references);
  if (references.issues.isNotEmpty) return references.issues;

  final invariants = IssueSink(ValidationLevel.invariants);
  if (catalog.nodes.isEmpty) {
    invariants.add(r'$.chapters', 'no_nodes', 'в каталоге нет ни одного узла', file: campaignFileName);
    return invariants.issues;
  }
  _checkChain(catalog, invariants);
  _checkKinds(catalog, invariants);
  _checkRewards(catalog, rules, invariants);
  _checkDecks(catalog, rules, invariants);
  return invariants.issues;
}

void _checkReferences(CampaignCatalog catalog, PackRules rules, Map<String, StringTable> strings, IssueSink sink) {
  void add(String path, String code, String message) => sink.add(path, code, message, file: campaignFileName);

  if (catalog.formatVersion != campaignFormatVersion) {
    add(
      r'$.format_version',
      'unsupported_campaign_format',
      'формат каталога ${catalog.formatVersion} не поддерживается, нужен $campaignFormatVersion',
    );
  }

  final keys = <String, String>{};
  void text(String path, String key) {
    if (!key.startsWith(campaignStringPrefix)) {
      add(path, 'invalid_string_key', 'ключ $key должен начинаться с $campaignStringPrefix');
    }
    keys.putIfAbsent(key, () => path);
  }

  bool known(String id) =>
      rules.squadCardsById.containsKey(id) ||
      rules.specialCardsById.containsKey(id) ||
      rules.leaderCardsById.containsKey(id);

  void grants(String path, List<CardGrant> items) {
    for (final (i, grant) in items.indexed) {
      if (!known(grant.cardId)) add('$path[$i].card_id', 'unknown_reference', 'нет карты или лидера ${grant.cardId}');
    }
  }

  text(r'$.starter_deck.name_key', catalog.starterDeck.nameKey);
  if (!rules.leaderCardsById.containsKey(catalog.starterDeck.leaderId)) {
    add(r'$.starter_deck.leader_id', 'unknown_reference', 'нет лидера ${catalog.starterDeck.leaderId}');
  }

  final chapterIds = <String>{};
  final nodeIds = <String>{};
  for (final (i, chapter) in catalog.chapters.indexed) {
    final path = '\$.chapters[$i]';
    if (!chapterIds.add(chapter.id)) add('$path.id', 'duplicate_id', 'глава ${chapter.id} указана дважды');
    text('$path.name_key', chapter.nameKey);
    for (final (j, node) in chapter.nodes.indexed) {
      final at = '$path.nodes[$j]';
      if (!nodeIds.add(node.id)) add('$at.id', 'duplicate_id', 'узел ${node.id} указан дважды');
      text('$at.opponent.name_key', node.opponent.nameKey);
      text('$at.theme_key', node.themeKey);
      grants('$at.reward', node.reward);
      if (node.bonus case final bonus?) grants('$at.bonus.reward', bonus.reward);
      grants('$at.opponent.deck', node.opponent.deck);
      if (node.opponent.fractionId case final id? when !rules.fractionsById.containsKey(id)) {
        add('$at.opponent.fraction_id', 'unknown_reference', 'нет фракции $id');
      }
      if (node.opponent.leaderId case final id? when !rules.leaderCardsById.containsKey(id)) {
        add('$at.opponent.leader_id', 'unknown_reference', 'нет лидера $id');
      }
    }
  }
  for (final (i, chapter) in catalog.chapters.indexed) {
    for (final (j, node) in chapter.nodes.indexed) {
      if (node.afterId case final after? when !nodeIds.contains(after)) {
        add('\$.chapters[$i].nodes[$j].after', 'unknown_reference', 'нет узла $after');
      }
    }
  }

  for (final MapEntry(key: locale, value: table) in strings.entries) {
    for (final MapEntry(:key, value: path) in keys.entries) {
      if (table[key] == null) add(path, 'missing_string', 'нет текста $key на языке $locale');
    }
    for (final key in table.entries.keys) {
      if (key.startsWith(campaignStringPrefix) && !keys.containsKey(key)) {
        sink.add('\$["$key"]', 'unused_string', 'текст не нужен каталогу кампании', file: stringsFileName(locale));
      }
    }
  }
}

void _checkChain(CampaignCatalog catalog, IssueSink sink) {
  void add(String path, String code, String message) => sink.add(path, code, message, file: campaignFileName);

  for (final (i, chapter) in catalog.chapters.indexed) {
    if (chapter.number != i + 1) {
      add('\$.chapters[$i].number', 'chapter_number', 'номер главы ${chapter.number}, ожидался ${i + 1}');
    }
  }
  final seen = <String, CampaignNode>{};
  var index = 0;
  for (final (i, chapter) in catalog.chapters.indexed) {
    for (final (j, node) in chapter.nodes.indexed) {
      final path = '\$.chapters[$i].nodes[$j]';
      final after = node.afterId;
      if (index == 0) {
        if (after != null) add('$path.after', 'first_node_after', 'у первого узла не должно быть предыдущего');
      } else if (after == null) {
        add('$path.after', 'missing_after', 'у узла ${node.id} нет узла, после которого он открывается');
      } else if (!seen.containsKey(after)) {
        add('$path.after', 'after_not_earlier', 'узел $after должен идти раньше ${node.id}');
      } else if (seen[after]!.kind == NodeKind.order) {
        add('$path.after', 'after_order', 'узел $after это заказ, он ничего не открывает');
      }
      seen[node.id] = node;
      index++;
    }
  }
}

void _checkKinds(CampaignCatalog catalog, IssueSink sink) {
  void add(String path, String code, String message) => sink.add(path, code, message, file: campaignFileName);

  for (final (i, chapter) in catalog.chapters.indexed) {
    for (final (j, node) in chapter.nodes.indexed) {
      final path = '\$.chapters[$i].nodes[$j]';
      final opponent = node.opponent;
      if (node.isScripted) {
        if (node.scenario == null) add('$path.scenario', 'missing_scenario', 'сценарному узлу нужен сценарий');
        if (opponent.fractionId != null || opponent.leaderId != null || opponent.deck.isNotEmpty) {
          add('$path.opponent', 'scripted_opponent', 'у сценарного узла есть только имя соперника');
        }
      } else {
        if (node.scenario != null) add('$path.scenario', 'unexpected_scenario', 'сценарий только у сценарного узла');
        if (opponent.fractionId == null || opponent.leaderId == null || opponent.deck.isEmpty) {
          add('$path.opponent', 'incomplete_opponent', 'нужны фракция, лидер и колода соперника');
        }
      }
    }
  }
}

void _checkRewards(CampaignCatalog catalog, PackRules rules, IssueSink sink) {
  void add(String path, String code, String message) => sink.add(path, code, message, file: campaignFileName);

  final granted = <String, int>{};
  for (final node in catalog.nodes) {
    for (final grant in [...node.reward, ...?node.bonus?.reward]) {
      granted.update(grant.cardId, (copies) => copies + grant.copies, ifAbsent: () => grant.copies);
    }
  }
  void card(String id, String name, int count) {
    final copies = granted[id] ?? 0;
    if (copies != count) add(r'$', 'card_copies', 'карта $name: выдано $copies копий, а в пакете $count');
  }

  for (final squad in rules.squadCards) {
    card(squad.id, squad.id, squad.count);
  }
  for (final special in rules.specialCards) {
    card(special.id, special.id, special.count);
  }
  for (final leader in rules.leaderCards) {
    card(leader.id, leader.id, 1);
  }

  final first = catalog.firstNode;
  if (!first.reward.any((grant) => grant.cardId == catalog.starterDeck.leaderId)) {
    add(r'$.starter_deck.leader_id', 'starter_leader', 'лидер стартовой колоды не выдан наградой первого узла');
  }
}

void _checkDecks(CampaignCatalog catalog, PackRules rules, IssueSink sink) {
  void add(String path, String code, String message) => sink.add(path, code, message, file: campaignFileName);

  for (final (i, chapter) in catalog.chapters.indexed) {
    for (final (j, node) in chapter.nodes.indexed) {
      final opponent = node.opponent;
      final fractionId = opponent.fractionId;
      if (node.isScripted || fractionId == null) continue;
      final path = '\$.chapters[$i].nodes[$j].opponent';
      final fraction = rules.fractionsById[fractionId]!;
      if (!fraction.isDeck) add('$path.fraction_id', 'not_a_deck_fraction', 'у фракции ${fraction.key} нет колоды');
      final leader = rules.leaderCardsById[opponent.leaderId]!;
      if (leader.fractionId != fractionId) add('$path.leader_id', 'leader_fraction', 'лидер из другой фракции');

      var units = 0;
      var specials = 0;
      final inDeck = <String>{};
      for (final (k, grant) in opponent.deck.indexed) {
        final at = '$path.deck[$k]';
        if (!inDeck.add(grant.cardId)) add(at, 'duplicate_card', 'карта указана дважды');
        final squad = rules.squadCardsById[grant.cardId];
        final special = rules.specialCardsById[grant.cardId];
        final cardFraction = squad?.fractionId ?? special?.fractionId;
        final count = squad?.count ?? special?.count;
        if (cardFraction == null || count == null) {
          add(at, 'leader_in_deck', 'в колоде лидер или неизвестная карта');
          continue;
        }
        if (cardFraction != fractionId && rules.fractionsById[cardFraction]!.isDeck) {
          add(at, 'foreign_card', 'карта другой фракции');
        }
        if (grant.copies > count) add(at, 'too_many_copies', 'копий ${grant.copies}, в пакете $count');
        if (squad != null) units += grant.copies;
        if (special != null) specials += grant.copies;
      }
      if (units < rules.gameRules.minSquadCards) {
        add('$path.deck', 'too_few_units', 'отрядов $units, нужно не меньше ${rules.gameRules.minSquadCards}');
      }
      if (specials > rules.gameRules.maxSpecialCards) {
        add(
          '$path.deck',
          'too_many_specials',
          'особых карт $specials, можно не больше ${rules.gameRules.maxSpecialCards}',
        );
      }
    }
  }
}

/// Строки кампании в пакете без каталога: они никому не нужны.
List<ValidationIssue> checkCampaignStringsWithoutCatalog(Map<String, StringTable> strings) {
  final sink = IssueSink(ValidationLevel.references);
  for (final MapEntry(key: locale, value: table) in strings.entries) {
    for (final key in table.entries.keys) {
      if (key.startsWith(campaignStringPrefix)) {
        sink.add('\$["$key"]', 'unused_string', 'в пакете нет каталога кампании', file: stringsFileName(locale));
      }
    }
  }
  return sink.issues;
}
