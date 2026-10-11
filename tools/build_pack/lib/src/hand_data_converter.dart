import 'package:gwent_build_pack/src/effect_mapping.dart';
import 'package:gwent_build_pack/src/hand_data_exception.dart';
import 'package:gwent_content/gwent_content.dart';

/// Правила и строки, полученные из `docs/hand/data`.
final class ConvertedContent {
  /// Создаёт результат конвертации.
  const ConvertedContent({required this.rules, required this.strings});

  /// Таблицы правил.
  final PackRules rules;

  /// Строки запасного языка.
  final StringTable strings;
}

/// Превращает таблицы `docs/hand/data` (имя таблицы → разобранный JSON) в правила и строки пакета.
///
/// - Тексты уходят в строки с ключами `<сущность>.<uuid>.<поле>`, в правилах остаются только ключи.
/// - Теги способностей сопоставляются с эффектами по таблицам из `effect_mapping.dart`.
/// - `twin_config`, `bait_config` и `mardrem_config` превращаются в параметры карт `summons` и `transform_to`.
/// - Записи каждой таблицы сортируются по UUID, чтобы одинаковые данные давали одинаковый пакет.
///
/// Неизвестный тег, битая связь или неверное поле дают [HandDataException] со всеми проблемами сразу.
/// Проверку готового пакета делает валидатор `gwent_content`.
ConvertedContent convertHandData(Map<String, Object?> tables) => _Converter(tables).convert();

final class _Converter {
  _Converter(this.tables);

  final Map<String, Object?> tables;
  final List<String> problems = [];
  final Map<String, String> strings = {};

  ConvertedContent convert() {
    final zones = _rows('zones');
    final zoneKeys = <String, ZoneKey>{};
    for (final row in zones) {
      final key = zoneKeysByTag[_string(row, 'tag')];
      if (key == null) {
        problems.add('zones ${_id(row)}: неизвестный tag ${row['tag']}');
      } else {
        zoneKeys[_id(row)] = key;
      }
    }

    final specialCards = _rows('special_cards');
    final specialIdsByTag = {for (final row in specialCards) _string(row, 'tag'): _id(row)};

    final squadCards = _rows('squad_cards');
    final squadAbilityTags = {for (final row in _rows('squad_card_abilities')) _id(row): _string(row, 'tag')};
    final cardParams = _squadCardParams(squadCards, squadAbilityTags, zoneKeys);

    final rules = PackRules(
      gameRules: _gameRules(),
      zones: [
        for (final row in _sorted(zones))
          Zone(id: _id(row), key: zoneKeys[_id(row)] ?? ZoneKey.melee, nameKey: _text('zone', row, 'name')),
      ],
      fractions: [
        for (final row in _sorted(_rows('fractions')))
          Fraction(
            id: _id(row),
            key: _fractionKey(row),
            isDeck: _bool(row, 'is_deck'),
            abilityId: _nullableString(row, 'ability_id'),
            nameKey: _text('fraction', row, 'name'),
          ),
      ],
      fractionAbilities: _abilities('fraction_abilities', 'fraction_ability', fractionEffectsByTag, specialIdsByTag),
      squadAbilities: _abilities('squad_card_abilities', 'squad_ability', squadEffectsByTag, specialIdsByTag),
      specialAbilities: _abilities('special_card_abilities', 'special_ability', specialEffectsByTag, specialIdsByTag),
      leaderAbilities: _abilities('leader_card_abilities', 'leader_ability', leaderEffectsByTag, specialIdsByTag),
      squadCards: [
        for (final row in _sorted(squadCards))
          SquadCard(
            id: _id(row),
            fractionId: _string(row, 'fraction_id'),
            zoneId: _string(row, 'zone_id'),
            strength: _int(row, 'strength'),
            isHero: _bool(row, 'is_hero'),
            count: _int(row, 'count'),
            abilityId: _nullableString(row, 'ability_id'),
            abilityParams: cardParams[_id(row)] ?? const {},
            nameKey: _text('squad_card', row, 'name'),
            descriptionKey: _text('squad_card', row, 'description'),
          ),
      ],
      specialCards: [
        for (final row in _sorted(specialCards))
          SpecialCard(
            id: _id(row),
            fractionId: _string(row, 'fraction_id'),
            abilityId: _string(row, 'ability_id'),
            abilityParams: const {},
            count: _int(row, 'count'),
            nameKey: _text('special_card', row, 'name'),
            descriptionKey: _text('special_card', row, 'description'),
          ),
      ],
      leaderCards: [
        for (final row in _sorted(_rows('leader_cards')))
          LeaderCard(
            id: _id(row),
            fractionId: _string(row, 'fraction_id'),
            abilityId: _string(row, 'ability_id'),
            abilityParams: const {},
            nameKey: _text('leader_card', row, 'name'),
            descriptionKey: _text('leader_card', row, 'description'),
          ),
      ],
    );
    if (problems.isNotEmpty) throw HandDataException(problems);
    return ConvertedContent(
      rules: rules,
      strings: StringTable(locale: fallbackLocale, entries: strings),
    );
  }

  String _fractionKey(Map<String, Object?> row) {
    final key = fractionKeysByTag[_string(row, 'tag')];
    if (key == null) problems.add('fractions ${_id(row)}: неизвестный tag ${row['tag']}');
    return key ?? '';
  }

  GameRules _gameRules() {
    final json = tables['game_rules'];
    if (json is! Map<String, Object?>) {
      problems.add('game_rules: ожидался объект');
      return const GameRules(crystals: 0, startingHandSize: 0, maxRedraws: 0, minSquadCards: 0, maxSpecialCards: 0);
    }
    return GameRules(
      crystals: _int(json, 'crystals'),
      startingHandSize: _int(json, 'starting_hand_size'),
      maxRedraws: _int(json, 'max_redraws'),
      minSquadCards: _int(json, 'min_squad_cards'),
      maxSpecialCards: _int(json, 'max_special_cards'),
    );
  }

  List<Ability> _abilities(
    String table,
    String entity,
    Map<String, EffectMapping> mappings,
    Map<String, String> specialIdsByTag,
  ) => [
    for (final row in _sorted(_rows(table)))
      if (mappings[_string(row, 'tag')] case final mapping?)
        Ability(
          id: _id(row),
          effect: mapping.effect,
          params: Map.unmodifiable({
            for (final MapEntry(:key, :value) in mapping.params.entries)
              key: value is SpecialCardTag ? _specialId(specialIdsByTag, value.tag, table) : value,
          }),
          nameKey: row.containsKey('name') ? _text(entity, row, 'name') : null,
          descriptionKey: _text(entity, row, 'description'),
        )
      else
        _unknownTag(table, row),
  ];

  Ability _unknownTag(String table, Map<String, Object?> row) {
    problems.add('$table ${_id(row)}: нет эффекта для tag ${row['tag']}');
    return Ability(id: _id(row), effect: EffectKey.medic, params: const {}, nameKey: null, descriptionKey: '');
  }

  String _specialId(Map<String, String> specialIdsByTag, String tag, String table) {
    final id = specialIdsByTag[tag];
    if (id == null) problems.add('$table: нет специальной карты с tag $tag');
    return id ?? '';
  }

  /// Параметры карт отрядов из таблиц связей: Двойник, Приманка, Берсерк, а также ряд Казни.
  Map<String, RawParams> _squadCardParams(
    List<Map<String, Object?>> cards,
    Map<String, String> abilityTags,
    Map<String, ZoneKey> zoneKeys,
  ) {
    final summons = _links('twin_config', 'squad_card_trigger_id', 'squad_card_slave_id');
    final baits = _links('bait_config', 'squad_card_trigger_id', 'squad_card_slave_id');
    final berserks = _links('mardrem_config', 'squad_card_before_id', 'squad_card_after_id');
    final params = <String, RawParams>{};
    final used = <String>{};

    for (final card in cards) {
      final id = _id(card);
      final tag = abilityTags[card['ability_id']];
      final effect = tag == null ? null : squadEffectsByTag[tag]?.effect;
      switch (effect) {
        case EffectKey.muster:
          params[id] = Map.unmodifiable({
            'summons': List<String>.unmodifiable(_required(summons, id, 'twin_config')..sort()),
          });
          used.add('twin_config $id');
        case EffectKey.bait:
          params[id] = Map.unmodifiable({'summons': _single(baits, id, 'bait_config')});
          used.add('bait_config $id');
        case EffectKey.berserk:
          params[id] = Map.unmodifiable({'transform_to': _single(berserks, id, 'mardrem_config')});
          used.add('mardrem_config $id');
        case EffectKey.scorchRow:
          final zone = zoneKeys[card['zone_id']];
          if (zone == null || zone == ZoneKey.agile) {
            problems.add('squad_cards $id: Казнь по ряду у карты без одного ряда');
          } else {
            params[id] = Map.unmodifiable({'row': zone.key});
          }
        case _:
          break;
      }
    }

    for (final (table, links) in [('twin_config', summons), ('bait_config', baits), ('mardrem_config', berserks)]) {
      for (final trigger in links.keys) {
        if (!used.contains('$table $trigger')) {
          problems.add('$table: карта $trigger не имеет нужной способности, связь некому использовать');
        }
      }
    }
    return params;
  }

  /// Связи таблицы [table]: UUID карты из [from] → UUID карт из [to] в порядке строк.
  Map<String, List<String>> _links(String table, String from, String to) {
    final links = <String, List<String>>{};
    for (final row in _rows(table)) {
      links.putIfAbsent(_string(row, from), () => []).add(_string(row, to));
    }
    return links;
  }

  List<String> _required(Map<String, List<String>> links, String id, String table) {
    final targets = links[id];
    if (targets == null || targets.isEmpty) problems.add('$table: нет связей для карты $id');
    return [...?targets];
  }

  String _single(Map<String, List<String>> links, String id, String table) {
    final targets = _required(links, id, table);
    if (targets.length > 1) problems.add('$table: у карты $id ${targets.length} связи, а нужна одна');
    return targets.isEmpty ? '' : targets.first;
  }

  /// Кладёт текст поля [field] записи [row] в строки и возвращает ключ `<entity>.<uuid>.<field>`.
  String _text(String entity, Map<String, Object?> row, String field) {
    final key = '$entity.${_id(row)}.$field';
    strings[key] = _string(row, field);
    return key;
  }

  List<Map<String, Object?>> _rows(String table) {
    final json = tables[table];
    if (json is! List<Object?>) {
      problems.add('$table: ожидался список записей');
      return const [];
    }
    return [
      for (final (i, row) in json.indexed)
        if (row is Map<String, Object?>) row else _badRow(table, i),
    ];
  }

  Map<String, Object?> _badRow(String table, int index) {
    problems.add('$table[$index]: ожидался объект');
    return const {};
  }

  List<Map<String, Object?>> _sorted(List<Map<String, Object?>> rows) =>
      [...rows]..sort((a, b) => _id(a).compareTo(_id(b)));

  String _id(Map<String, Object?> row) => row['id'] is String ? row['id']! as String : '';

  String _string(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is String) return value;
    problems.add('${row['id'] ?? '?'}: поле $field должно быть строкой');
    return '';
  }

  String? _nullableString(Map<String, Object?> row, String field) => row[field] == null ? null : _string(row, field);

  int _int(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is int) return value;
    problems.add('${row['id'] ?? field}: поле $field должно быть целым числом');
    return 0;
  }

  bool _bool(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is bool) return value;
    problems.add('${row['id'] ?? '?'}: поле $field должно быть true или false');
    return false;
  }
}
