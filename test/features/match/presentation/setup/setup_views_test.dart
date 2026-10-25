import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_issue_text.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent/src/features/match/presentation/setup/deck_select_view.dart';
import 'package:gwent/src/features/match/presentation/setup/faction_select_view.dart';
import 'package:gwent_engine/gwent_engine.dart' show Faction;

import '../../../../support/fonts.dart';
import '../../../../support/localized_app.dart';
import '../../../../support/match_fixtures.dart';
import '../../../../support/screen_guards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late DeckRules rules;
  late AppLocalizations l10n;
  late CardContentMapper mapper;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    content = await loadBaseContent();
    rules = await GameContentDeckRulesSource(LoadGameContent(AssetContentSource.basePack(rootBundle))).load();
    mapper = CardContentMapper(pack: rules.pack, l10n: l10n);
  });

  Future<void> pump(WidgetTester tester, Widget view, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedScreen(view));
    await tester.pump();
    expectNoFallbackTextStyle(tester);
    expectBackButtonAtEdge(tester);
  }

  group('FactionSelectView', () {
    Widget view({int index = 0, void Function(int)? onIndex, VoidCallback? onConfirm, bool enabled = true}) =>
        FactionSelectView(
          eyebrow: 'Шаг 1 из 2',
          factions: rules.factionInfos,
          index: index,
          onIndexChanged: onIndex ?? (_) {},
          onConfirm: onConfirm ?? () {},
          onBack: () {},
          confirmEnabled: enabled,
        );

    testWidgets('показывает фракцию и её способность; кнопка подтверждает', (tester) async {
      var confirmed = 0;
      await pump(tester, view(onConfirm: () => confirmed++));
      final first = rules.factionInfos.first;

      expect(find.text(first.name), findsOneWidget);
      expect(find.textContaining(first.perk), findsOneWidget);
      await tester.tap(find.text(l10n.factionSelectConfirm));
      expect(confirmed, 1);
    });

    testWidgets('стрелка листает на следующую фракцию', (tester) async {
      final shown = <int>[];
      await pump(tester, view(onIndex: shown.add));

      await tester.tap(find.bySemanticsLabel(l10n.factionSelectNext));
      await tester.pump(FactionSelectView.pageDuration + const Duration(milliseconds: 50));

      expect(shown, [1]);
    });

    testWidgets('погашенная кнопка не подтверждает', (tester) async {
      var confirmed = 0;
      await pump(tester, view(enabled: false, onConfirm: () => confirmed++));

      await tester.tap(find.text(l10n.factionSelectConfirm), warnIfMissed: false);

      expect(confirmed, 0);
    });

    testWidgets('на маленьком экране ничего не переполняется, заголовок не заходит под «Назад»', (tester) async {
      await pump(tester, view(index: 1), size: const Size(320, 568));
      expect(tester.takeException(), isNull);

      final back = tester.getRect(find.bySemanticsLabel(l10n.setupBack));
      final title = tester.getRect(find.text(l10n.factionSelectTitle));
      expect(title.left, greaterThanOrEqualTo(back.right));
    });

    testWidgets('точки карусели нажимаются зоной не меньше 44 pt', (tester) async {
      final shown = <int>[];
      await pump(tester, view(onIndex: shown.add));

      final dot = find.bySemanticsLabel(RegExp(rules.factionInfos[2].name));
      expect(tester.getSize(dot.first).shortestSide, greaterThanOrEqualTo(44));
    });
  });

  group('DeckSelectView', () {
    Deck deck(String id, String name, {bool small = false}) {
      final full = realDeck(content, Faction.skellige, id: id);
      final cards = small ? {full.cards.keys.first: 1} : full.cards;
      return full.copyWith(name: name, cards: cards);
    }

    Widget view(
      List<DeckChoice> choices, {
      String? selected,
      void Function(String)? onEdit,
      VoidCallback? onPlay,
      void Function(String)? onSelect,
    }) {
      final faction = rules.factionInfos.firstWhere((faction) => faction.key == 'skellige');
      return DeckSelectView(
        eyebrow: 'Перед матчем',
        choices: choices,
        selectedId: selected,
        faction: (name: faction.name, look: GwentFaction.fromKey(faction.key)),
        leaderOf: (deck) => switch (faction.leader(deck.leaderId)) {
          final leader? => (
            name: leader.name,
            face: mapper.leader(rules.pack.rules.leaderCardsById[leader.id]!).face,
          ),
          null => null,
        },
        issueText: DeckIssueText(pack: rules.pack, l10n: l10n),
        playLabel: l10n.deckSelectPlay,
        onSelect: onSelect ?? (_) {},
        onEdit: onEdit ?? (_) {},
        onPlay: onPlay ?? () {},
        onBack: () {},
      );
    }

    testWidgets('негодная колода помечена, причина видна, «Играть» не нажимается', (tester) async {
      var played = 0;
      final bad = deck('bad', 'Мало карт', small: true);
      final choice = DeckChoice(deck: bad, issues: rules.check(bad));
      await pump(tester, view([choice], selected: 'bad', onPlay: () => played++));

      expect(choice.issues, isNotEmpty);
      expect(find.text('Мало карт'), findsOneWidget);
      expect(find.text(l10n.deckSelectNotReady), findsOneWidget);
      await tester.tap(find.text(l10n.deckSelectPlay), warnIfMissed: false);
      expect(played, 0);
    });

    testWidgets('годная колода играется, «Изменить» открывает её в конструкторе', (tester) async {
      var played = 0;
      final edited = <String>[];
      final good = deck('good', 'Годная');
      await pump(
        tester,
        view(
          [DeckChoice(deck: good, issues: const [])],
          selected: 'good',
          onPlay: () => played++,
          onEdit: edited.add,
        ),
      );

      expect(find.text(l10n.deckSelectReady), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Годная'))).value,
        contains(l10n.deckSelectReady),
        reason: 'скринридер называет состояние колоды',
      );
      await tester.tap(find.text(l10n.deckSelectPlay));
      await tester.tap(find.text(l10n.deckSelectEdit));
      expect(played, 1);
      expect(edited, ['good']);
    });

    testWidgets('в строке стоит лидер самой колоды, у колод с разными лидерами они разные', (tester) async {
      final faction = rules.factionInfos.firstWhere((faction) => faction.key == 'skellige');
      final first = deck('first', 'Первая').copyWith(leaderId: faction.leaders.first.id);
      final second = deck('second', 'Вторая').copyWith(leaderId: faction.leaders.last.id);
      await pump(
        tester,
        view([
          DeckChoice(deck: first, issues: const []),
          DeckChoice(deck: second, issues: const []),
        ], selected: 'first'),
      );

      expect(find.text(shortLeaderName(faction.leaders.first.name)), findsOneWidget);
      expect(find.text(shortLeaderName(faction.leaders.last.name)), findsOneWidget);
    });

    testWidgets('лидера колоды нет в пакете: строка без лидера, ничего не падает', (tester) async {
      final stale = deck('stale', 'Старая').copyWith(leaderId: 'нет-такого');
      await pump(tester, view([DeckChoice(deck: stale, issues: const [])], selected: 'stale'));

      expect(find.text('Старая'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('несколько колод на маленьком экране: список прокручивается, ничего не переполняется', (tester) async {
      final choices = [
        for (var i = 0; i < 8; i++) DeckChoice(deck: deck('d$i', 'Колода $i'), issues: const []),
      ];
      await pump(tester, view(choices, selected: 'd0'), size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });
  });
}
