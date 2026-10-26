import 'package:gwent_content/gwent_content.dart';

import 'sample_pack.dart';

Map<String, Object?> _grant(String cardId, [int copies = 1]) => {'card_id': cardId, 'copies': copies};

Map<String, Object?> _node(
  String nodeId,
  String kind,
  String? after, {
  required List<Map<String, Object?>> reward,
  Map<String, Object?>? bonus,
  List<Map<String, Object?>>? deck,
}) => {
  'id': nodeId,
  'kind': kind,
  'after': after,
  'opponent': {
    'name_key': 'campaign.node.$nodeId.opponent',
    if (deck != null) ...{'fraction_id': Ids.skellige, 'leader_id': Ids.leader, 'deck': deck},
  },
  'difficulty': 'easy',
  'theme_key': 'campaign.node.$nodeId.theme',
  if (kind == 'scripted') 'scenario': 'first_match',
  'reward': reward,
  'bonus': ?bonus,
};

/// Каталог кампании для [samplePackJson]: награды в сумме дают ровно `count` каждой карты и по одному лидеру.
Map<String, Object?> sampleCampaignJson() => {
  'format_version': campaignFormatVersion,
  'starter_deck': {'name_key': 'campaign.starter_deck.name', 'leader_id': Ids.leader},
  'chapters': [
    {
      'id': 'c1',
      'number': 1,
      'name_key': 'campaign.chapter.c1.name',
      'released': true,
      'nodes': [
        _node('n-00', 'scripted', null, reward: [_grant(Ids.leader), _grant(Ids.hero), _grant(Ids.bond, 2)]),
        _node(
          'n-01',
          'duel',
          'n-00',
          reward: [_grant(Ids.spy)],
          bonus: {
            'condition': 'win_2_0',
            'reward': [_grant(Ids.frost, 2)],
          },
          deck: [
            _grant(Ids.muster, 3),
            _grant(Ids.bond, 2),
            _grant(Ids.berserk),
            _grant(Ids.scorcher),
            _grant(Ids.frost),
          ],
        ),
        _node(
          'n-02',
          'order',
          'n-01',
          reward: [_grant(Ids.cow)],
          deck: [_grant(Ids.muster, 3), _grant(Ids.bond, 2), _grant(Ids.berserk)],
        ),
      ],
    },
    {
      'id': 'c2',
      'number': 2,
      'name_key': 'campaign.chapter.c2.name',
      'released': false,
      'nodes': [
        _node(
          'n-03',
          'boss',
          'n-01',
          reward: [_grant(Ids.muster, 3), _grant(Ids.berserk), _grant(Ids.scorcher), _grant(Ids.frost)],
          deck: [_grant(Ids.muster, 3), _grant(Ids.bond, 2), _grant(Ids.scorcher)],
        ),
      ],
    },
  ],
};

/// Строки для [samplePackJson] и [sampleCampaignJson].
Map<String, Object?> sampleStringsWithCampaignJson([Map<String, Object?>? campaign]) {
  final keys = <String>{};
  void collect(Object? json) {
    switch (json) {
      case Map<String, Object?>():
        for (final MapEntry(:key, :value) in json.entries) {
          if (key.endsWith('_key') && value is String) keys.add(value);
          collect(value);
        }
      case List<Object?>():
        json.forEach(collect);
    }
  }

  collect(campaign ?? sampleCampaignJson());
  return {...sampleStringsJson(), for (final key in keys) key: 'текст $key'};
}

/// Файлы пакета с каталогом кампании.
Map<String, List<int>> buildCampaignFiles({Map<String, Object?>? campaign, Map<String, Object?>? strings}) {
  final catalog = decodeCampaign(campaign ?? sampleCampaignJson());
  final decodedRules = decodeRules(samplePackJson());
  final decodedStrings = decodeStrings(fallbackLocale, strings ?? sampleStringsWithCampaignJson(campaign));
  return buildContentPack(
    identity: sampleIdentity,
    rules: (decodedRules as Decoded<PackRules>).value,
    strings: {fallbackLocale: (decodedStrings as Decoded<StringTable>).value},
    campaign: (catalog as Decoded<CampaignCatalog>).value,
  ).files.map((path, bytes) => MapEntry(path, [...bytes]));
}
