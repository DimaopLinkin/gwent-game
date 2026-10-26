import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

import 'support/sample_campaign.dart';
import 'support/sample_pack.dart';

void main() {
  Future<PackLoadResult> load(Map<String, List<int>> files) =>
      ContentPackLoader(engine: fullEngine).load(InMemoryContentSource(files));

  /// Коды проблем, с которыми пакет с каталогом [campaign] отклоняется (пусто, если принят).
  Future<List<String>> codes(Map<String, Object?> campaign, {Map<String, Object?>? strings}) async {
    final files = buildCampaignFiles(campaign: campaign, strings: strings);
    return switch (await load(files)) {
      PackLoaded() => const [],
      PackRejected(:final issues) => [for (final issue in issues) issue.code],
    };
  }

  List<Map<String, Object?>> nodesOf(Map<String, Object?> campaign) => [
    for (final chapter in (campaign['chapters']! as List<Object?>).cast<Map<String, Object?>>())
      ...(chapter['nodes']! as List<Object?>).cast<Map<String, Object?>>(),
  ];

  Map<String, Object?> node(Map<String, Object?> campaign, String nodeId) =>
      nodesOf(campaign).firstWhere((node) => node['id'] == nodeId);

  test('пакет с каталогом загружается, каталог читается', () async {
    final pack = (await load(buildCampaignFiles()) as PackLoaded).pack;
    final campaign = pack.campaign!;
    expect(campaign.chapters.map((chapter) => chapter.id), ['c1', 'c2']);
    expect(campaign.nodes.map((node) => node.id), ['n-00', 'n-01', 'n-02', 'n-03']);
    expect(campaign.firstNode.isScripted, isTrue);
    expect(campaign.nodesById['n-01']!.bonus!.condition, BonusCondition.winTwoZero);
    expect(campaign.chapterOf('n-03')!.released, isFalse);
    expect(pack.text(campaign.nodesById['n-01']!.opponent.nameKey), startsWith('текст campaign.node.n-01'));
  });

  test('каталог без узлов отклоняется, а не валит загрузку', () async {
    final campaign = sampleCampaignJson();
    for (final chapter in (campaign['chapters']! as List<Object?>).cast<Map<String, Object?>>()) {
      chapter['nodes'] = <Object?>[];
    }
    expect(await codes(campaign), contains('no_nodes'));
  });

  test('пакет без каталога допустим', () async {
    final pack = (await load(buildSampleFiles()) as PackLoaded).pack;
    expect(pack.campaign, isNull);
  });

  test('каталог читается обратно без потерь, сборка детерминирована', () {
    final first = buildCampaignFiles();
    expect(first[campaignFileName], buildCampaignFiles()[campaignFileName]);
    final decoded = (decodeCampaign(sampleCampaignJson()) as Decoded<CampaignCatalog>).value;
    expect(encodeCampaign(decoded), sampleCampaignJson());
  });

  group('схема', () {
    test('неизвестное поле, вид и условие', () {
      final campaign = sampleCampaignJson();
      node(campaign, 'n-01')
        ..['kind'] = 'dance'
        ..['extra'] = 1;
      (node(campaign, 'n-01')['bonus']! as Map<String, Object?>)['condition'] = 'win_hard';
      final result = decodeCampaign(campaign) as DecodeFailed<CampaignCatalog>;
      expect(result.issues.map((issue) => issue.code), containsAll(['unknown_value', 'unknown_field']));
    });

    test('нулевое число копий', () {
      final campaign = sampleCampaignJson();
      ((node(campaign, 'n-01')['reward']! as List<Object?>).first! as Map<String, Object?>)['copies'] = 0;
      expect(decodeCampaign(campaign), isA<DecodeFailed<CampaignCatalog>>());
    });
  });

  group('ссылки', () {
    test('неизвестная карта в награде', () async {
      final campaign = sampleCampaignJson();
      ((node(campaign, 'n-01')['reward']! as List<Object?>).first! as Map<String, Object?>)['card_id'] = id(9999);
      expect(await codes(campaign), contains('unknown_reference'));
    });

    test('узел после несуществующего', () async {
      final campaign = sampleCampaignJson();
      node(campaign, 'n-01')['after'] = 'n-77';
      expect(await codes(campaign), contains('unknown_reference'));
    });

    test('нет текста для ключа и лишний текст кампании', () async {
      final strings = sampleStringsWithCampaignJson()
        ..remove('campaign.node.n-01.theme')
        ..['campaign.node.stray.theme'] = 'лишний';
      expect(await codes(sampleCampaignJson(), strings: strings), unorderedEquals(['missing_string', 'unused_string']));
    });

    test('строки кампании без каталога лишние', () async {
      final files = buildSampleFiles(strings: sampleStringsWithCampaignJson());
      expect(switch (await load(files)) {
        PackRejected(:final issues) => issues.map((issue) => issue.code),
        PackLoaded() => const <String>[],
      }, contains('unused_string'));
    });
  });

  group('инварианты', () {
    test('копий выдано меньше и больше count', () async {
      final fewer = sampleCampaignJson();
      node(fewer, 'n-02')['reward'] = [
        {'card_id': Ids.spy, 'copies': 1},
      ];
      expect(await codes(fewer), contains('card_copies'));
      final more = sampleCampaignJson();
      ((node(more, 'n-03')['reward']! as List<Object?>).first! as Map<String, Object?>)['copies'] = 4;
      expect(await codes(more), contains('card_copies'));
    });

    test('лидер выдан дважды', () async {
      final campaign = sampleCampaignJson();
      (node(campaign, 'n-02')['reward']! as List<Object?>).add({'card_id': Ids.leader, 'copies': 1});
      expect(await codes(campaign), contains('card_copies'));
    });

    test('цепочка: заказ ничего не открывает, предыдущий узел идёт раньше, первый без предыдущего', () async {
      final order = sampleCampaignJson();
      node(order, 'n-03')['after'] = 'n-02';
      expect(await codes(order), contains('after_order'));

      final later = sampleCampaignJson();
      node(later, 'n-01')['after'] = 'n-03';
      expect(await codes(later), contains('after_not_earlier'));

      final first = sampleCampaignJson();
      node(first, 'n-00')['after'] = 'n-01';
      expect(await codes(first), contains('first_node_after'));

      final none = sampleCampaignJson();
      node(none, 'n-02')['after'] = null;
      expect(await codes(none), contains('missing_after'));
    });

    test('сценарный узел без сценария и обычный с ним', () async {
      final scripted = sampleCampaignJson();
      node(scripted, 'n-00').remove('scenario');
      expect(await codes(scripted), contains('missing_scenario'));
      final duel = sampleCampaignJson();
      node(duel, 'n-01')['scenario'] = 'first_match';
      expect(await codes(duel), contains('unexpected_scenario'));
    });

    test('колода соперника: слишком мало отрядов, лишние копии, чужой лидер', () async {
      final few = sampleCampaignJson();
      (node(few, 'n-03')['opponent']! as Map<String, Object?>)['deck'] = [
        {'card_id': Ids.muster, 'copies': 3},
      ];
      expect(await codes(few), contains('too_few_units'));

      final copies = sampleCampaignJson();
      (node(copies, 'n-03')['opponent']! as Map<String, Object?>)['deck'] = [
        {'card_id': Ids.muster, 'copies': 6},
      ];
      expect(await codes(copies), contains('too_many_copies'));

      final leader = sampleCampaignJson();
      (node(leader, 'n-03')['opponent']! as Map<String, Object?>)['fraction_id'] = Ids.neutral;
      expect(await codes(leader), containsAll(['not_a_deck_fraction', 'leader_fraction']));
    });

    test('лидер стартовой колоды не выдан первым узлом', () async {
      final campaign = sampleCampaignJson();
      final reward = node(campaign, 'n-00')['reward']! as List<Object?>;
      reward.removeWhere((grant) => (grant! as Map<String, Object?>)['card_id'] == Ids.leader);
      (node(campaign, 'n-02')['reward']! as List<Object?>).add({'card_id': Ids.leader, 'copies': 1});
      expect(await codes(campaign), contains('starter_leader'));
    });
  });
}
