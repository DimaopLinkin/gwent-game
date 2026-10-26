import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_examples.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_topic.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_cubit.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_screen.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_state.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_texts.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_topic_screen.dart';
import 'package:gwent_content/gwent_content.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  Future<HowToPlayCubit> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double textScale = 1,
    ContentSource? source,
    bool waitForContent = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = HowToPlayCubit(LoadGameContent(source ?? AssetContentSource.basePack(rootBundle)));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: localizedScreen(screen),
        ),
      ),
    );
    if (waitForContent) {
      await tester.runAsync(() async {
        while (cubit.state is HowToPlayLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
    }
    return cubit;
  }

  group('список тем', () {
    testWidgets('восемь тем с подписями, нажатие открывает тему, «назад» и «Пройти первую партию» работают', (
      tester,
    ) async {
      final opened = <HowToTopic>[];
      var backs = 0;
      var tutorials = 0;
      await pumpScreen(
        tester,
        HowToPlayScreen(onOpen: opened.add, onBack: () => backs++, onTutorial: () => tutorials++),
        waitForContent: false,
      );
      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text(l10n.howToTitle), findsOneWidget);
      for (final topic in HowToTopic.values) {
        final texts = HowToTexts(topic, l10n);
        expect(find.text(texts.title), findsOneWidget, reason: texts.title);
        expect(find.text(texts.summary), findsOneWidget, reason: texts.summary);
        expect(tester.getSize(find.text(texts.title)).height, greaterThan(0));
      }

      await tester.tap(find.text(l10n.howToWeatherTitle));
      expect(opened, [HowToTopic.weather]);

      await tester.tap(find.text(l10n.howToStartTutorial));
      expect(tutorials, 1);

      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      expect(backs, 1);
    });

    testWidgets('поверх партии кнопки «Пройти первую партию» нет', (tester) async {
      await pumpScreen(tester, HowToPlayScreen(onOpen: (_) {}, onBack: () {}), waitForContent: false);
      expect(find.text(l10n.howToStartTutorial), findsNothing);
    });

    testWidgets('строки не меньше 72 pt и целиком помещаются на 360 pt без прокрутки', (tester) async {
      await pumpScreen(
        tester,
        HowToPlayScreen(onOpen: (_) {}, onBack: () {}, onTutorial: () {}),
        size: const Size(360, 800),
        waitForContent: false,
      );
      for (final topic in HowToTopic.values) {
        final row = find.ancestor(of: find.text(HowToTexts(topic, l10n).title), matching: find.byType(ConstrainedBox));
        expect(tester.getSize(row.first).height, greaterThanOrEqualTo(72));
      }
      expect(tester.getBottomLeft(find.text(l10n.howToStartTutorial)).dy, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('крупный шрифт ×1,3 на 360 pt: ничего не переполняется, последняя тема и кнопка достижимы прокруткой', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        HowToPlayScreen(onOpen: (_) {}, onBack: () {}, onTutorial: () {}),
        size: const Size(360, 800),
        textScale: 1.3,
        waitForContent: false,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text(l10n.howToStartTutorial), 200);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.howToStartTutorial), findsOneWidget);
    });
  });

  group('страницы тем', () {
    for (final topic in HowToTopic.values) {
      testWidgets('«${topic.key}» читается целиком на 360 pt и шрифте ×1,3', (tester) async {
        final texts = HowToTexts(topic, l10n);
        await pumpScreen(
          tester,
          HowToTopicScreen(topic: topic, onBack: () {}, onOpen: (_) {}),
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expectNoFallbackTextStyle(tester);
        expectBackButtonAtEdge(tester);
        expect(find.text(texts.title), findsOneWidget);
        for (final paragraph in texts.paragraphs) {
          expect(find.text(paragraph), findsOneWidget);
        }
        await tester.scrollUntilVisible(find.text(texts.remember), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(texts.remember), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('соседние темы: у первой нет «Предыдущей», у последней «Следующей», нажатие переходит', (tester) async {
      final opened = <HowToTopic>[];
      await pumpScreen(
        tester,
        HowToTopicScreen(topic: HowToTopic.goal, onBack: () {}, onOpen: opened.add),
      );
      await tester.scrollUntilVisible(
        find.text(l10n.howToGoalRemember),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining(l10n.howToPreviousTopic), findsNothing);
      await tester.tap(find.textContaining(l10n.howToNextTopic));
      expect(opened, [HowToTopic.handAndDeck]);

      await pumpScreen(
        tester,
        HowToTopicScreen(topic: HowToTopic.leadersAndFactions, onBack: () {}, onOpen: opened.add),
      );
      await tester.scrollUntilVisible(
        find.text(l10n.howToLeadersRemember),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining(l10n.howToNextTopic), findsNothing);
      await tester.tap(find.textContaining(l10n.howToPreviousTopic));
      expect(opened.last, HowToTopic.specials);
    });

    testWidgets('«Ряды и сила»: мини-поле на настоящих картах и счёт равен сумме силы рядов', (tester) async {
      await pumpScreen(
        tester,
        HowToTopicScreen(topic: HowToTopic.rowsAndPower, onBack: () {}, onOpen: (_) {}),
      );
      expect(find.byType(GwentCard), findsNWidgets(4));
      // Реданский пехотинец 1 + Боец Синих Полосок 4 + Кейра Мец 5 + Баллиста 6 (силы из пакета карт).
      expect(find.text(l10n.howToScore(16)), findsOneWidget);
    });

    testWidgets('«Способности отрядов»: десять карт-примеров с названием и фразой', (tester) async {
      await pumpScreen(
        tester,
        HowToTopicScreen(topic: HowToTopic.abilities, onBack: () {}, onOpen: (_) {}),
      );
      for (final name in [l10n.howToAbilityTightBondName, l10n.howToAbilitySpyName, l10n.howToAbilityHeroName]) {
        await tester.scrollUntilVisible(find.text(name), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(name), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Лидеры и фракции»: пять фракций с названиями и перками из пакета', (tester) async {
      await pumpScreen(
        tester,
        HowToTopicScreen(topic: HowToTopic.leadersAndFactions, onBack: () {}, onOpen: (_) {}),
      );
      for (final faction in ['Королевства Севера', 'Нильфгаард', 'Чудовища', "Скоя'таэли", 'Скеллиге']) {
        await tester.scrollUntilVisible(find.text(faction), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(faction), findsOneWidget);
      }
      expect(find.text(l10n.howToFactionPerkMissing), findsNothing, reason: 'перки берутся из пакета');
    });

    testWidgets('набор карт не загрузился: тексты на месте, примеров нет, ошибок нет', (tester) async {
      final cubit = await pumpScreen(
        tester,
        HowToTopicScreen(topic: HowToTopic.rowsAndPower, onBack: () {}, onOpen: (_) {}),
        source: InMemoryContentSource(const {}),
      );
      expect(cubit.state, isA<HowToPlayUnavailable>());
      expect(find.text(l10n.howToRowsAndPowerText1), findsOneWidget);
      expect(find.byType(GwentCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  test('все карты-примеры есть в пакете карт', () async {
    final result = await LoadGameContent(AssetContentSource.basePack(rootBundle))();
    if (result is! GameContentReady) fail('набор карт не загрузился: $result');
    final rules = result.content.pack.rules;
    final ids = [
      for (final ability in HowToAbility.values) ability.cardId,
      for (final special in HowToSpecial.values) special.cardId,
      for (final weather in HowToWeather.values) weather.cardId,
      ...HowToRowExamples.melee,
      ...HowToRowExamples.ranged,
      ...HowToRowExamples.siege,
      HowToLeaderExample.cardId,
    ];
    for (final id in ids) {
      final known =
          rules.squadCardsById.containsKey(id) ||
          rules.specialCardsById.containsKey(id) ||
          rules.leaderCardsById.containsKey(id);
      expect(known, isTrue, reason: 'карты $id нет в пакете');
    }
  });
}
