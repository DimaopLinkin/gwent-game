import 'package:gwent_content/gwent_content.dart';

/// Сколько копий карты может быть у игрока: `count` карты в пакете; у лидера одна; у неизвестной карты ноль.
int cardCopyLimit(PackRules rules, String cardId) =>
    rules.squadCardsById[cardId]?.count ??
    rules.specialCardsById[cardId]?.count ??
    (rules.leaderCardsById.containsKey(cardId) ? 1 : 0);
