import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_issue_text.dart';
import 'package:gwent_content/gwent_content.dart' as content;
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/deck_rules_fixtures.dart';

void main() {
  late AppLocalizations l10n;
  late DeckIssueText text;

  setUpAll(() async => l10n = await AppLocalizations.delegate.load(const Locale('ru')));

  setUp(() {
    final pack = content.ContentPack(
      manifest: smallPack.manifest,
      rules: smallPack.rules,
      strings: {
        'ru': content.StringTable(
          locale: 'ru',
          entries: const {'card.c-cerys.name': 'Цирилла'},
        ),
      },
    );
    text = DeckIssueText(pack: pack, l10n: l10n);
  });

  test('карта называется по строкам пакета', () {
    expect(
      text.describe(const DeckRuleViolation(WrongFaction(CardId(Small.cerys)))),
      l10n.deckIssueWrongFaction('Цирилла'),
    );
    expect(
      text.describe(const DeckRuleViolation(TooManyCopies(CardId(Small.cerys), count: 2, max: 1))),
      l10n.deckIssueTooManyCopies('Цирилла', 2, 1),
    );
  });

  test('кампания: закрытый лидер, закрытая карта и нехватка открытых копий', () {
    expect(text.describe(const LeaderNotOwned(Small.crach)), l10n.deckIssueLeaderNotOpened);
    expect(
      text.describe(const CardNotOwned(cardId: Small.cerys, copies: 1, owned: 0)),
      l10n.deckIssueCardNotOpened('Цирилла'),
    );
    expect(
      text.describe(const CardNotOwned(cardId: Small.cerys, copies: 3, owned: 2)),
      l10n.deckIssueCardFewOpened('Цирилла', 3, 2),
    );
  });

  test('карты нет в пакете: показан её идентификатор', () {
    expect(
      text.describe(const DeckRuleViolation(CreatedCardInDeck(CardId('нет такой')))),
      l10n.deckIssueCreatedCard('нет такой'),
    );
  });

  test('числа в нарушениях попадают во фразу', () {
    expect(
      text.describe(const DeckRuleViolation(TooFewUnitCards(count: 3, min: 5))),
      l10n.deckIssueTooFewUnits(5, 3),
    );
    expect(
      text.describe(const DeckRuleViolation(TooManySpecialCards(count: 4, max: 2))),
      l10n.deckIssueTooManySpecials(2, 4),
    );
  });

  test('лидеры и неизвестная карта', () {
    expect(
      text.describe(const LeaderOfOtherFaction(leaderId: Small.eredin, leaderFactionId: Small.monsters)),
      l10n.deckIssueLeaderOfOtherFaction,
    );
    expect(text.describe(const DeckRuleViolation(UnknownLeader(LeaderId('x')))), l10n.deckIssueLeaderUnavailable);
    expect(text.describe(const DeckRuleViolation(UnknownCard(CardId('x')))), l10n.deckIssueUnknownCard);
  });

  test('первая проблема списка; у годной колоды ничего', () {
    expect(text.firstOf(const []), isNull);
    expect(
      text.firstOf(const [
        LeaderOfOtherFaction(leaderId: Small.eredin, leaderFactionId: Small.monsters),
        DeckRuleViolation(UnknownCard(CardId('x'))),
      ]),
      l10n.deckIssueLeaderOfOtherFaction,
    );
  });
}
