import 'dart:convert';
import 'dart:io';

import 'package:gwent_build_pack/src/campaign_converter.dart';
import 'package:gwent_build_pack/src/campaign_decks.dart';
import 'package:gwent_build_pack/src/hand_data_converter.dart';
import 'package:gwent_build_pack/src/hand_data_exception.dart';
import 'package:gwent_content/gwent_content.dart';

/// Имя файла с рецептами колод противников в `docs/hand/campaign`.
const String campaignRecipesFile = 'deck_recipes.json';

/// Собирает колоды всех несценарных узлов по рецептам из [campaignDir] и возвращает содержимое
/// `opponent_decks.json` (узел → список карт с именами для чтения человеком).
///
/// Фракцию и уровень узла берёт из `chapters.json`, рецепт (теги и сид) из `deck_recipes.json`. Узел без
/// рецепта и рецепт без узла это ошибка [HandDataException].
Map<String, Object?> generateOpponentDecks({required Map<String, Object?> tables, required Directory campaignDir}) {
  final converted = convertHandData(tables);
  final chapters = _object(_readJson(File('${campaignDir.path}/$campaignChaptersFile')));
  final recipes = _object(_object(_readJson(File('${campaignDir.path}/$campaignRecipesFile')))['recipes']);

  final problems = <String>[];
  final decks = <String, Object?>{};
  final seen = <String>{};
  for (final chapter in _list(chapters['chapters'])) {
    for (final nodeJson in _list(_object(chapter)['nodes'])) {
      final node = _object(nodeJson);
      final nodeId = node['id']! as String;
      if (node['kind'] == NodeKind.scripted.key) continue;
      seen.add(nodeId);
      final recipe = recipes[nodeId];
      if (recipe == null) {
        problems.add('нет рецепта колоды для узла $nodeId');
        continue;
      }
      final recipeObject = _object(recipe);
      final tags = <DeckTag>[];
      for (final name in _list(recipeObject['tags'])) {
        final tag = DeckTag.byName(name! as String);
        if (tag == null) {
          problems.add('$nodeId: неизвестный тег $name');
        } else {
          tags.add(tag);
        }
      }
      final difficulty = CampaignDifficulty.fromKey(node['difficulty']! as String);
      final fractionId = _object(node['opponent'])['fraction_id'];
      if (difficulty == null || fractionId is! String) {
        problems.add('$nodeId: нет уровня или фракции');
        continue;
      }
      final deck = buildOpponentDeck(
        rules: converted.rules,
        fractionId: fractionId,
        difficulty: difficulty,
        recipe: DeckRecipe(tags: tags, seed: recipeObject['seed']! as int),
      );
      decks[nodeId] = [
        for (final grant in deck)
          {
            'card_id': grant.cardId,
            'name': _nameOf(converted, grant.cardId),
            'copies': grant.copies,
          },
      ];
    }
  }
  for (final nodeId in recipes.keys) {
    if (!seen.contains(nodeId)) problems.add('рецепт для неизвестного или сценарного узла $nodeId');
  }
  if (problems.isNotEmpty) throw HandDataException(problems);
  return {'decks': decks};
}

String _nameOf(ConvertedContent converted, String cardId) {
  final rules = converted.rules;
  final key = rules.squadCardsById[cardId]?.nameKey ?? rules.specialCardsById[cardId]!.nameKey;
  return converted.strings[key]!;
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

Map<String, Object?> _object(Object? json) =>
    json is Map<String, Object?> ? json : throw const HandDataException(['ожидался объект']);

List<Object?> _list(Object? json) => json is List<Object?> ? json : throw const HandDataException(['ожидался список']);
