import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/match_history/application/watch_match_history.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/presentation/history_cubit.dart';
import 'package:gwent/src/features/match_history/presentation/history_screen.dart';
import 'package:gwent/src/features/match_history/presentation/history_state.dart';

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/match_fixtures.dart';
import '../../../support/screen_guards.dart';

final class _BrokenRulesSource implements DeckRulesSource {
  @override
  Future<DeckRules> load() async => throw StateError('набор карт не загрузился');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeckRules rules;
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    await loadBaseContent();
    rules = await GameContentDeckRulesSource(LoadGameContent(AssetContentSource.basePack(rootBundle))).load();
  });

  late InMemoryMatchHistoryRepository repository;
  final opened = <String>[];
  var backs = 0;

  setUp(() {
    repository = InMemoryMatchHistoryRepository();
    opened.clear();
    backs = 0;
  });

  String factionId(String key) => rules.factionInfos.firstWhere((info) => info.key == key).id;

  MatchRecord record(
    String id, {
    MatchOutcome outcome = MatchOutcome.victory,
    MatchMode mode = MatchMode.ai,
    String? opponentName,
    bool hasReplay = true,
    int minute = 0,
  }) => MatchRecord(
    id: id,
    mode: mode,
    playerFactionId: factionId('skellige'),
    opponentFactionId: factionId('monsters'),
    opponentName: opponentName,
    outcome: outcome,
    roundsWon: 2,
    roundsLost: 1,
    finishedAt: DateTime.utc(2026, 10, 25, 12, minute),
    hasReplay: hasReplay,
  );

  Future<HistoryCubit> pumpHistory(
    WidgetTester tester, {
    DeckRulesSource? source,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = HistoryCubit(WatchMatchHistory(repository), LoadDeckRules(source ?? FakeDeckRulesSource(rules)));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      localizedScreen(
        BlocProvider.value(
          value: cubit,
          child: HistoryScreen(onOpen: opened.add, onBack: () => backs++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expectNoFallbackTextStyle(tester);
    expectBackButtonAtEdge(tester);
    return cubit;
  }

  testWidgets('пустая история говорит об этом', (tester) async {
    await pumpHistory(tester);

    expect(find.text(l10n.historyEmpty), findsOneWidget);
  });

  testWidgets('партия: итог, счёт, фракции, режим и имя соперника, дата', (tester) async {
    await repository.add(record('a', mode: MatchMode.wifi, opponentName: 'Вереск'));
    await pumpHistory(tester);

    expect(find.text(l10n.historyOutcomeVictory.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.historyRounds(2, 1)), findsOneWidget);
    expect(find.text(l10n.historyVersus('Скеллиге', 'Чудовища')), findsOneWidget);
    expect(find.text(l10n.historyModeWithOpponent(l10n.historyModeWifi, 'Вереск')), findsOneWidget);
    final local = DateTime.utc(2026, 10, 25, 12).toLocal();
    expect(find.text(l10n.historyWhen(local, local)), findsOneWidget);
    expect(find.text(l10n.historyWatch.toUpperCase()), findsOneWidget);
  });

  testWidgets('режимы называются каждый своим словом', (tester) async {
    var minute = 0;
    for (final mode in MatchMode.values) {
      await repository.add(record(mode.name, mode: mode, minute: minute++));
    }
    await pumpHistory(tester);

    for (final label in [
      l10n.historyModeHotSeat,
      l10n.historyModeAi,
      l10n.historyModeWifi,
      l10n.historyModeBluetooth,
      l10n.historyModeOnline,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('итоги: победа, поражение и ничья', (tester) async {
    await repository.add(record('w'));
    await repository.add(record('l', outcome: MatchOutcome.defeat, minute: 1));
    await repository.add(record('d', outcome: MatchOutcome.draw, minute: 2));
    await pumpHistory(tester);

    for (final label in [l10n.historyOutcomeVictory, l10n.historyOutcomeDefeat, l10n.historyOutcomeDraw]) {
      expect(find.text(label.toUpperCase()), findsOneWidget, reason: label);
    }
  });

  testWidgets('тап по партии с реплеем открывает его; без реплея партия не открывается', (tester) async {
    final handle = tester.ensureSemantics();
    await repository.add(record('with'));
    await repository.add(record('without', hasReplay: false, minute: 5));
    await pumpHistory(tester);

    expect(find.text(l10n.historyNoReplay), findsOneWidget);
    await tester.tap(find.text(l10n.historyNoReplay));
    expect(opened, isEmpty);

    await tester.tap(find.bySemanticsLabel(RegExp('^${l10n.historyOpenSemantics('')}')));
    expect(opened, ['with']);
    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    expect(backs, 1);
    handle.dispose();
  });

  testWidgets('сначала последние; новая партия появляется в списке сама', (tester) async {
    await repository.add(record('old'));
    await pumpHistory(tester);
    expect(find.text(l10n.historyOutcomeVictory.toUpperCase()), findsOneWidget);

    await repository.add(record('new', outcome: MatchOutcome.defeat, minute: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final defeat = tester.getTopLeft(find.text(l10n.historyOutcomeDefeat.toUpperCase())).dy;
    final victory = tester.getTopLeft(find.text(l10n.historyOutcomeVictory.toUpperCase())).dy;
    expect(defeat, lessThan(victory));
  });

  testWidgets('набор карт не загрузился: партии видны без названий фракций', (tester) async {
    await repository.add(record('a'));
    await pumpHistory(tester, source: _BrokenRulesSource());

    expect(find.text(l10n.historyOutcomeVictory.toUpperCase()), findsOneWidget);
    expect(find.textContaining('Скеллиге'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('на узком экране строка не переполняется', (tester) async {
    await repository.add(record('a', mode: MatchMode.wifi, opponentName: 'Очень длинное имя соперника по сети'));
    await pumpHistory(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
  });

  test('состояние: загрузка, затем список', () async {
    final cubit = HistoryCubit(WatchMatchHistory(repository), LoadDeckRules(FakeDeckRulesSource(rules)));
    addTearDown(cubit.close);
    expect(cubit.state, isA<HistoryLoading>());

    await repository.add(record('a'));
    final loaded = await cubit.stream.firstWhere((state) => state is HistoryLoaded) as HistoryLoaded;

    expect(loaded.records.map((record) => record.id), ['a']);
    expect(loaded.factions[factionId('skellige')]?.name, 'Скеллиге');
  });
}
