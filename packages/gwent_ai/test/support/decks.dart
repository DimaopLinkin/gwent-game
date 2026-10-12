import 'package:gwent_engine/gwent_engine.dart';

/// Колоды фракций из фикстур и все лидеры каждой фракции: партии бота проходят через все способности.
final List<({List<String> leaders, List<String> cards})> factionDecks = [
  (
    leaders: ['crach', 'bran'],
    cards: [
      'berserk',
      'young_berserk',
      'young_berserk',
      'mysovur',
      'cerys',
      'drummond',
      'drummond',
      'kambi',
      'pirate',
      'olaf',
      'udalryk',
      'mardrem',
      'cow',
      'dandelion',
      'footman',
      'archer',
      'frost',
      'storm',
      'clear',
      'decoy',
      'scorch',
      'horn',
    ],
  ),
  (
    leaders: ['emgyr_take', 'emgyr_reveal', 'emgyr_white_flame', 'emgyr_random_medic'],
    cards: [
      'skellen',
      'mysterious_elf',
      'archer_medic',
      'archer_medic',
      'villentretenmerth',
      'yennefer',
      'vesemir',
      'geralt',
      'dandelion',
      'footman',
      'footman',
      'archer',
      'archer',
      'fog',
      'rain',
      'decoy',
      'horn',
      'scorch',
      'clear',
    ],
  ),
  (
    leaders: ['eredin_oberon', 'eredin_return', 'eredin_weather', 'eredin_spies'],
    cards: [
      'arachas',
      'arachas',
      'arachas',
      'behemoth',
      'nekker',
      'kejran',
      'harpy',
      'ghoul',
      'ghoul',
      'ghoul',
      'villentretenmerth',
      'yennefer',
      'vesemir',
      'geralt',
      'cow',
      'fog',
      'rain',
      'frost',
      'clear',
      'decoy',
      'horn',
      'scorch',
    ],
  ),
  (
    leaders: ['foltest_siege_scorch', 'foltest_fog', 'foltest_clear', 'foltest_horn'],
    cards: [
      'blue_stripes',
      'blue_stripes',
      'blue_stripes',
      'kaedwen_siege',
      'kaedwen_siege',
      'kaedwen_siege',
      'thaler',
      'banner_medic',
      'catapult',
      'catapult',
      'poor_infantry',
      'poor_infantry',
      'dandelion',
      'footman',
      'archer',
      'frost',
      'fog',
      'horn',
      'decoy',
      'scorch',
    ],
  ),
  (
    leaders: ['francesca_agile', 'francesca_daisy', 'francesca_frost'],
    cards: [
      'elf_skirmisher',
      'elf_skirmisher',
      'elf_skirmisher',
      'schirru',
      'vesemir',
      'geralt',
      'yennefer',
      'footman',
      'footman',
      'archer',
      'archer',
      'cow',
      'frost',
      'fog',
      'decoy',
      'horn',
    ],
  ),
];

/// Колода фракции [faction] (номер в [factionDecks]) с лидером номер [leader] по кругу.
Deck deckOf(int faction, int leader) {
  final source = factionDecks[faction % factionDecks.length];
  return Deck(
    leader: LeaderId(source.leaders[leader % source.leaders.length]),
    cards: [for (final card in source.cards) CardId(card)],
  );
}

/// Пара колод для партии с сидом [seed]: перебирает пары фракций, зеркала и всех лидеров.
MatchSetup setupFor(int seed) {
  final count = factionDecks.length;
  return MatchSetup(
    one: deckOf(seed % count, seed ~/ count),
    two: deckOf(seed ~/ count % count, seed),
    rng: SeededRng(seed),
  );
}
