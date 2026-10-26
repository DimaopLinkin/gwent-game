import 'dart:convert';
import 'dart:io';

import 'package:gwent_build_pack/gwent_build_pack.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Каталог кампании из настоящих данных: награды сходятся с картами, колоды противников воспроизводимы,
/// фракции становятся доступны на тех узлах, что названы в `docs/spec/campaign-nodes.md`.
void main() {
  late ContentPack pack;
  late PackRules rules;
  late CampaignCatalog campaign;

  setUpAll(() async {
    final (_, result) = await buildAndVerify(realTables(), realIdentity(), campaign: realCampaignSource());
    if (result case PackRejected(:final issues)) fail('пакет отклонён:\n${issues.join('\n')}');
    pack = (result as PackLoaded).pack;
    rules = pack.rules;
    campaign = pack.campaign!;
  });

  test('4 главы, 49 узлов, выпущена только первая', () {
    expect(campaign.chapters.map((chapter) => chapter.nodes.length), [10, 13, 15, 11]);
    expect(campaign.chapters.map((chapter) => chapter.released), [true, false, false, false]);
    expect(campaign.firstNode.id, 'c1-00');
    expect(campaign.firstNode.scenario, 'first_match');
    expect(pack.text(campaign.chapters.first.nameKey), 'Белый сад');
  });

  test('копии наград в сумме дают count каждой карты, каждый лидер выдан один раз', () {
    final granted = <String, int>{};
    for (final node in campaign.nodes) {
      for (final grant in [...node.reward, ...?node.bonus?.reward]) {
        granted.update(grant.cardId, (copies) => copies + grant.copies, ifAbsent: () => grant.copies);
      }
    }
    void expectCopies(String cardId, String nameKey, int count) =>
        expect(granted[cardId] ?? 0, count, reason: pack.text(nameKey));
    for (final card in rules.squadCards) {
      expectCopies(card.id, card.nameKey, card.count);
    }
    for (final card in rules.specialCards) {
      expectCopies(card.id, card.nameKey, card.count);
    }
    for (final leader in rules.leaderCards) {
      expect(granted[leader.id], 1, reason: pack.text(leader.nameKey));
    }
  });

  test('колоды противников воспроизводятся рецептами, руками их не правят', () {
    final generated = generateOpponentDecks(tables: realTables(), campaignDir: campaignDir);
    final committed = jsonDecode(File('${campaignDir.path}/$campaignDecksFile').readAsStringSync());
    expect(jsonDecode(jsonEncode(generated)), committed, reason: 'перегенерируйте: dart run bin/campaign_decks.dart');
  });

  test('у каждого узла кроме сценарного есть колода, лидер и фракция противника', () {
    for (final node in campaign.nodes.where((node) => !node.isScripted)) {
      expect(node.opponent.deck, isNotEmpty, reason: node.id);
      expect(rules.leaderCardsById[node.opponent.leaderId]!.fractionId, node.opponent.fractionId, reason: node.id);
    }
  });

  test('фракция становится доступной после узла из campaign-nodes.md: лидер и 22 отряда с нейтральными', () {
    final neutral = rules.fractions.singleWhere((fraction) => !fraction.isDeck).id;
    final owned = <String, int>{};
    final availableAt = <String, String>{};
    for (final node in campaign.nodes) {
      for (final grant in node.reward) {
        owned.update(grant.cardId, (copies) => copies + grant.copies, ifAbsent: () => grant.copies);
      }
      for (final fraction in rules.fractions.where((fraction) => fraction.isDeck)) {
        if (availableAt.containsKey(fraction.key)) continue;
        final hasLeader = rules.leaderCards.any(
          (leader) => leader.fractionId == fraction.id && owned.containsKey(leader.id),
        );
        final units = rules.squadCards
            .where((card) => card.fractionId == fraction.id || card.fractionId == neutral)
            .fold(0, (sum, card) => sum + (owned[card.id] ?? 0));
        if (hasLeader && units >= rules.gameRules.minSquadCards) availableAt[fraction.key] = node.id;
      }
    }
    expect(availableAt, {
      'northern_realms': 'c1-00',
      'monsters': 'c2-06',
      'scoia_tael': 'c2-08',
      'nilfgaardian_empire': 'c3-04',
      'skellige': 'c4-03',
    });
  });

  group('конвертер', () {
    CampaignSource edited(void Function(Map<String, Object?> chapters) change) {
      final chapters = jsonDecode(jsonEncode(realCampaignSource().chapters)) as Map<String, Object?>;
      change(chapters);
      return CampaignSource(chapters: chapters, decks: realCampaignSource().decks);
    }

    Future<void> expectProblem(CampaignSource source, String part) async {
      await expectLater(
        () => buildAndVerify(realTables(), realIdentity(), campaign: source),
        throwsA(
          isA<HandDataException>().having((e) => e.problems.join('\n'), 'problems', contains(part)),
        ),
      );
    }

    Map<String, Object?> node(Map<String, Object?> chapters, String nodeId) => [
      for (final chapter in (chapters['chapters']! as List<Object?>).cast<Map<String, Object?>>())
        ...(chapter['nodes']! as List<Object?>).cast<Map<String, Object?>>(),
    ].firstWhere((node) => node['id'] == nodeId);

    test('имя карты в данных не совпадает с пакетом', () async {
      final source = edited((chapters) {
        final reward = node(chapters, 'c1-01')['reward']! as List<Object?>;
        (reward.first! as Map<String, Object?>)['name'] = 'Не та карта';
      });
      await expectProblem(source, 'Не та карта');
    });

    test('у узла нет колоды', () async {
      final source = CampaignSource(
        chapters: realCampaignSource().chapters,
        decks: {'decks': <String, Object?>{}},
      );
      await expectProblem(source, 'нет колоды для узла c1-01');
    });

    test('пакет без данных кампании собирается без каталога', () async {
      final (_, result) = await buildAndVerify(realTables(), realIdentity());
      expect((result as PackLoaded).pack.campaign, isNull);
    });
  });
}
