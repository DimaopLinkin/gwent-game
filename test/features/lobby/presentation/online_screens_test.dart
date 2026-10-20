import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/get_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/presentation/create_online_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/create_online_game_screen.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_screen.dart';
import 'package:gwent/src/features/lobby/presentation/play_method_screen.dart';
import 'package:gwent/src/features/lobby/presentation/room_code_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_screen.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';
import '../support/online_harness.dart';

/// Ширины телефонов, на которых проверяется вёрстка: от iPhone SE до iPhone 14 Pro.
const List<double> _widths = [320, 360, 393];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  late InMemorySettingsRepository settings;
  late OnlineHarness online;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  setUp(() {
    settings = InMemorySettingsRepository();
    online = OnlineHarness(settings);
  });

  /// Размер телефона и закрытие игр после теста: сетевой код живёт на настоящих часах, поэтому закрываем вне фальшивых.
  void usePhone(WidgetTester tester, {double width = 390, double height = 844}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.runAsync(online.close));
  }

  /// Закрывает держатель после теста: остановку потоков ждут, крутя `pump`.
  void closeAfterTest(WidgetTester tester, BlocBase<Object?> cubit) => addTearDown(() async {
    var done = false;
    final closing = cubit.close().whenComplete(() => done = true);
    for (var i = 0; i < 20 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await closing;
  });

  /// Пускает время сетевого кода вперёд и показывает результат: сервис и хост отвечают по часам стенда.
  Future<void> settle(WidgetTester tester, {int rounds = 12}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => online.scheduler.elapse(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Строка не распалась на буквы: высота текста не больше двух строк его кегля.
  void expectNotBroken(WidgetTester tester, Finder text, {int lines = 2}) {
    final style = tester.widget<Text>(text).style;
    final size = tester.getSize(text);
    final line = (style?.fontSize ?? 14) * (style?.height ?? 1.4);
    expect(size.height, lessThanOrEqualTo(line * lines + 1), reason: 'текст переносится по буквам: $size');
  }

  GwentButton buttonLabelled(WidgetTester tester, String label) =>
      tester.widget<GwentButton>(find.widgetWithText(GwentButton, label));

  group('выбор способа', () {
    testWidgets('«Через интернет» меняет кнопки: комната и код; Wi-Fi возвращает прежние', (tester) async {
      usePhone(tester);
      final created = <PlayMethod>[];
      final found = <PlayMethod>[];
      await tester.pumpWidget(
        localizedScreen(PlayMethodScreen(onCreate: created.add, onFind: found.add, onBack: () {})),
      );

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text(l10n.netCreateGame), findsOneWidget);
      expect(find.text(l10n.netFindGame), findsOneWidget);

      await tester.tap(find.text(l10n.netMethodInternet));
      await tester.pump();
      expect(find.text(l10n.netCreateGame), findsNothing);
      await tester.tap(find.text(l10n.netCreateRoom));
      await tester.tap(find.text(l10n.netEnterCode));

      await tester.tap(find.text(l10n.netMethodWifi));
      await tester.pump();
      await tester.tap(find.text(l10n.netCreateGame));
      await tester.tap(find.text(l10n.netFindGame));

      expect(created, [PlayMethod.internet, PlayMethod.wifi]);
      expect(found, [PlayMethod.internet, PlayMethod.wifi]);
    });

    testWidgets('экран открывается сразу с интернетом, если игрок вернулся из онлайн-комнаты', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        localizedScreen(
          PlayMethodScreen(initial: PlayMethod.internet, onCreate: (_) {}, onFind: (_) {}, onBack: () {}),
        ),
      );

      expect(find.text(l10n.netCreateRoom), findsOneWidget);
      expect(find.text(l10n.netEnterCode), findsOneWidget);
    });

    for (final width in _widths) {
      testWidgets('ширина ${width.toInt()}: три способа и две кнопки умещаются, текст не ломается', (tester) async {
        usePhone(tester, width: width, height: 568);
        await tester.pumpWidget(
          localizedScreen(
            PlayMethodScreen(initial: PlayMethod.internet, onCreate: (_) {}, onFind: (_) {}, onBack: () {}),
          ),
        );

        expect(tester.takeException(), isNull);
        expectNotBroken(tester, find.text(l10n.netMethodInternet));
        expectNotBroken(tester, find.text(l10n.netMethodWifi));
        // Кнопки прижаты к низу и целиком на экране.
        final bottom = tester.getBottomLeft(find.widgetWithText(GwentButton, l10n.netEnterCode)).dy;
        expect(bottom, lessThanOrEqualTo(568));
      });
    }
  });

  group('создание комнаты', () {
    Future<CreateOnlineGameCubit> pumpCreate(
      WidgetTester tester, {
      VoidCallback? onCreated,
      VoidCallback? onBack,
      double width = 390,
    }) async {
      usePhone(tester, width: width);
      final cubit = CreateOnlineGameCubit(online.hostGame, WatchSettings(settings), fallbackName: 'Игрок');
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: CreateOnlineGameScreen(onCreated: onCreated ?? () {}, onBack: onBack ?? () {}),
          ),
        ),
      );
      return cubit;
    }

    testWidgets('показывает загрузку, создаёт комнату на сервере и сообщает экрану', (tester) async {
      var created = 0;
      await pumpCreate(tester, onCreated: () => created++);

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text(l10n.netOnlineCreating), findsOneWidget);

      await settle(tester);

      expect(created, 1);
      expect(online.server.rooms, hasLength(1));
      expect(online.hostActive.current, isNotNull);
    });

    testWidgets('сервис спит: «Сервис недоступен», «Повторить» создаёт комнату, когда он проснулся', (tester) async {
      var created = 0;
      online.server.offline = true;
      await pumpCreate(tester, onCreated: () => created++);

      await settle(tester);
      expect(find.text(l10n.netNoticeServiceTitle), findsOneWidget);
      expect(find.text(l10n.netNoticeServiceText), findsOneWidget);
      expectNoFallbackTextStyle(tester);
      expect(created, 0);

      online.server.offline = false;
      await tester.tap(find.text(l10n.netNoticeRetry));
      await settle(tester);

      expect(created, 1);
    });

    testWidgets('слишком много комнат за час: понятная причина и «Назад»', (tester) async {
      var backs = 0;
      online.hostRooms.createFailure = LobbyFailure.tooManyRooms;
      await pumpCreate(tester, onBack: () => backs++);

      await settle(tester);
      expect(find.text(l10n.netNoticeTooManyRoomsTitle), findsOneWidget);

      await tester.tap(find.text(l10n.netNoticeBack));
      expect(backs, 1);
    });

    for (final width in _widths) {
      testWidgets('ширина ${width.toInt()}: сообщение о недоступном сервисе умещается', (tester) async {
        online.server.offline = true;
        await pumpCreate(tester, width: width);

        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text(l10n.netNoticeServiceTitle), findsOneWidget);
        expectNotBroken(tester, find.text(l10n.netNoticeServiceTitle).first);
      });
    }
  });

  group('ввод кода', () {
    Future<NetworkGame> openRoom(WidgetTester tester) async {
      final opened = await tester.runAsync(() => online.hostGame(gameName: 'Цири', playerName: 'Цири'));
      return (opened! as NetworkGameOpened).game;
    }

    Future<String> roomCode(WidgetTester tester) async =>
        (await tester.runAsync(() => online.codeOf(online.hostActive)))!.code.value;

    Future<void> pumpJoin(
      WidgetTester tester, {
      VoidCallback? onJoined,
      VoidCallback? onBack,
      double width = 390,
      double height = 844,
    }) async {
      usePhone(tester, width: width, height: height);
      final cubit = JoinOnlineGameCubit(online.joinGame, WatchSettings(settings), fallbackName: 'Гость');
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: JoinOnlineGameScreen(onJoined: onJoined ?? () {}, onBack: onBack ?? () {}),
          ),
        ),
      );
      await tester.pump();
    }

    String fieldText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('«Войти» недоступна, пока нет шести знаков; ввод приводится к заглавным без дефисов и пробелов', (
      tester,
    ) async {
      await pumpJoin(tester);

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(buttonLabelled(tester, l10n.netOnlineJoin).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'ab-c d');
      await tester.pump();
      expect(fieldText(tester), 'ABCD');
      expect(buttonLabelled(tester, l10n.netOnlineJoin).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'abc-def-ghi');
      await tester.pump();
      expect(fieldText(tester), 'ABCDEF');
      expect(buttonLabelled(tester, l10n.netOnlineJoin).onPressed, isNotNull);
    });

    testWidgets('верный код: гость входит, хост видит запрос, экран уходит в комнату', (tester) async {
      var joined = 0;
      final host = await openRoom(tester);
      final code = await roomCode(tester);
      await pumpJoin(tester, onJoined: () => joined++);

      await tester.enterText(find.byType(TextField), code.toLowerCase());
      await tester.pump();
      await tester.tap(find.text(l10n.netOnlineJoin));
      await tester.pump();
      expect(find.text(l10n.netOnlineJoining), findsOneWidget);
      await settle(tester);

      expect(joined, 1);
      expect(online.guestActive.current, isNotNull);
      expect(host.room.pendingGuest, 'Гость');
    });

    testWidgets('неверный код: сообщение под полем, код остаётся, правка убирает сообщение', (tester) async {
      await openRoom(tester);
      await pumpJoin(tester);

      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.pump();
      await tester.tap(find.text(l10n.netOnlineJoin));
      await settle(tester);

      expect(find.text(l10n.netNoticeCodeNotFoundTitle), findsOneWidget);
      expect(find.text(l10n.netNoticeCodeNotFoundText), findsOneWidget);
      expect(fieldText(tester), 'ZZZZZZ');
      expectNoFallbackTextStyle(tester);

      await tester.enterText(find.byType(TextField), 'ZZZZZ');
      await tester.pump();
      expect(find.text(l10n.netNoticeCodeNotFoundTitle), findsNothing);
    });

    testWidgets('знаки вне алфавита кода (0, 1, I, O): подсказка, к серверу экран не обращается', (tester) async {
      await pumpJoin(tester);

      await tester.enterText(find.byType(TextField), 'AB0DEF');
      await tester.pump();
      await tester.tap(find.text(l10n.netOnlineJoin));
      await tester.pump();

      expect(find.text(l10n.netOnlineBadCode), findsOneWidget);
      expect(online.guestRooms.calls, isEmpty);
    });

    testWidgets('слишком много неверных кодов: сообщение про лимит', (tester) async {
      await openRoom(tester);
      await pumpJoin(tester);
      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.pump();

      for (var i = 0; i < 9; i++) {
        await tester.tap(find.text(l10n.netOnlineJoin));
        await settle(tester, rounds: 3);
      }

      expect(find.text(l10n.netNoticeTooManyAttemptsTitle), findsOneWidget);
      expect(find.text(l10n.netNoticeTooManyAttemptsText), findsOneWidget);
    });

    testWidgets('сервис спит: «Сервис недоступен», код остаётся, повтор входит', (tester) async {
      var joined = 0;
      await openRoom(tester);
      final code = await roomCode(tester);
      await pumpJoin(tester, onJoined: () => joined++);
      online.server.offline = true;

      await tester.enterText(find.byType(TextField), code);
      await tester.pump();
      await tester.tap(find.text(l10n.netOnlineJoin));
      await settle(tester);
      expect(find.text(l10n.netNoticeServiceTitle), findsOneWidget);
      expect(fieldText(tester), code);

      online.server.offline = false;
      await tester.tap(find.text(l10n.netOnlineJoin));
      await settle(tester);
      expect(joined, 1);
    });

    testWidgets('код своей комнаты и занятой комнаты объясняются', (tester) async {
      final host = await openRoom(tester);
      final code = await roomCode(tester);
      // Гость уже занял место в комнате.
      await tester.runAsync(() async {
        final opened = await online.elapseUntil(
          online.phone('first').byAddress(await online.codeOf(online.hostActive), playerName: 'Вереск'),
        );
        await online.settle();
        host.admitGuest();
        await online.settle();
        return opened;
      });
      await pumpJoin(tester);

      await tester.enterText(find.byType(TextField), code);
      await tester.pump();
      await tester.tap(find.text(l10n.netOnlineJoin));
      await settle(tester);

      expect(find.text(l10n.netNoticeRoomFullTitle), findsOneWidget);
      expect(find.text(l10n.netNoticeRoomFullText), findsOneWidget);
    });

    for (final width in _widths) {
      testWidgets('ширина ${width.toInt()}: код и сообщение об ошибке умещаются, клавиатура не закрывает кнопку', (
        tester,
      ) async {
        await openRoom(tester);
        await pumpJoin(tester, width: width, height: 568);
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);

        await tester.enterText(find.byType(TextField), 'ZZZZZZ');
        await tester.pump();
        await tester.tap(find.text(l10n.netOnlineJoin));
        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text(l10n.netNoticeCodeNotFoundTitle), findsOneWidget);
        final button = find.widgetWithText(GwentButton, l10n.netOnlineJoin);
        expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(568 - 260), reason: 'кнопку закрыла клавиатура');
        expect(tester.getSize(find.byType(TextField)).width, lessThanOrEqualTo(width));
      });
    }
  });

  group('комната у хоста', () {
    late LoadDeckRules loadRules;

    setUp(() {
      loadRules = LoadDeckRules(
        GameContentDeckRulesSource(LoadGameContent(AssetContentSource.basePack(rootBundle))),
      );
    });

    Future<NetworkGame> hosted(WidgetTester tester) async {
      final opened = await tester.runAsync(() => online.hostGame(gameName: 'Цири', playerName: 'Цири'));
      return (opened! as NetworkGameOpened).game;
    }

    Future<void> pumpRoom(
      WidgetTester tester,
      NetworkGame game, {
      double width = 390,
      double height = 844,
      VoidCallback? onLeft,
    }) async {
      usePhone(tester, width: width, height: height);
      final room = RoomCubit(game, loadRules, GetDeck(InMemoryDeckRepository([])));
      closeAfterTest(tester, room);
      await tester.pumpWidget(
        localizedScreen(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: room),
              // Держатель кода закрывается вместе с экраном: его таймер не должен пережить дерево.
              if (game.isHost)
                BlocProvider(create: (_) => RoomCodeCubit(game, refresh: const Duration(milliseconds: 200))),
            ],
            child: RoomScreen(
              isHost: game.isHost,
              online: true,
              title: game.title ?? '',
              onPickDeck: (_) async => null,
              onBuildDeck: (_) async => null,
              onShowQr: () {},
              onStarted: () {},
              onLeft: onLeft ?? () {},
            ),
          ),
        ),
      );
      await settle(tester, rounds: 3);
    }

    testWidgets('хост видит крупный код комнаты и подсказку для соперника, без QR', (tester) async {
      final host = await hosted(tester);
      final code = (await tester.runAsync(() => online.codeOf(online.hostActive)))!.code;
      await pumpRoom(tester, host);

      expectNoFallbackTextStyle(tester);
      expect(find.text(code.formatted), findsOneWidget);
      expect(find.text(l10n.netOnlineCodeCaption), findsOneWidget);
      expect(find.text(l10n.netOnlineWaitHint), findsOneWidget);
      expect(find.text(l10n.netQrShow), findsNothing);
      expect(find.bySemanticsLabel(l10n.netOnlineCodeSemantics(code.value.split('').join(' '))), findsOneWidget);
    });

    testWidgets('«Скопировать код» кладёт код в буфер и сообщает об этом', (tester) async {
      final host = await hosted(tester);
      final code = (await tester.runAsync(() => online.codeOf(online.hostActive)))!.code;
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpRoom(tester, host);

      await tester.tap(find.text(l10n.netOnlineCodeCopy));
      await tester.pump();

      expect(copied, code.formatted);
      expect(find.text(l10n.netOnlineCodeCopied), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(l10n.netOnlineCodeCopy), findsOneWidget);
    });

    testWidgets('гость ушёл, комната создана заново: на экране новый код', (tester) async {
      final host = await hosted(tester);
      final first = (await tester.runAsync(() => online.codeOf(online.hostActive)))!.code;
      await pumpRoom(tester, host);
      final guest = await tester.runAsync(() async {
        final joined = await online.elapseUntil(
          online.joinGame.byAddress(await online.codeOf(online.hostActive), playerName: 'Вереск'),
        );
        await online.settle();
        host.admitGuest();
        await online.settle();
        return (joined as NetworkGameOpened).game;
      });
      await settle(tester, rounds: 3);

      await tester.runAsync(() async {
        await guest!.leave();
        await online.settle();
        await online.scheduler.elapse(const Duration(seconds: 2));
      });
      await settle(tester);

      final next = (await tester.runAsync(() => online.codeOf(online.hostActive)))!.code;
      expect(next, isNot(first));
      expect(find.text(next.formatted), findsOneWidget);
      expect(find.text(first.formatted), findsNothing);
    });

    testWidgets('гость постучался: хост видит запрос с именем', (tester) async {
      final host = await hosted(tester);
      await pumpRoom(tester, host);
      await tester.runAsync(
        () async => online.elapseUntil(
          online.joinGame.byAddress(await online.codeOf(online.hostActive), playerName: 'Вереск'),
        ),
      );

      await settle(tester, rounds: 3);

      expect(find.text(l10n.netAdmitTitle('Вереск')), findsOneWidget);
    });

    testWidgets('«Отмена» спрашивает про комнату и код, а не про Wi-Fi', (tester) async {
      final host = await hosted(tester);
      await pumpRoom(tester, host);

      await tester.tap(find.text(l10n.dialogCancel));
      await tester.pump();

      expect(find.text(l10n.netLeaveBodyHostOnline), findsOneWidget);
    });

    testWidgets('подзаголовок лобби говорит «Интернет»', (tester) async {
      final host = await hosted(tester);
      await pumpRoom(tester, host);
      await tester.runAsync(() async {
        await online.elapseUntil(
          online.joinGame.byAddress(await online.codeOf(online.hostActive), playerName: 'Вереск'),
        );
        await online.settle();
        host.admitGuest();
        await online.settle();
      });

      await settle(tester, rounds: 3);

      expect(find.text(l10n.netRoomSubtitleOnline('Цири')), findsOneWidget);
    });

    testWidgets('хост закрыл комнату: гость читает про новый код, а не про поиск', (tester) async {
      final host = await hosted(tester);
      final guest = await tester.runAsync(() async {
        final joined = await online.elapseUntil(
          online.joinGame.byAddress(await online.codeOf(online.hostActive), playerName: 'Вереск'),
        );
        await online.settle();
        host.admitGuest();
        await online.settle();
        return (joined as NetworkGameOpened).game;
      });
      await pumpRoom(tester, guest!);

      await tester.runAsync(() async {
        await host.leave();
        await online.settle();
        await online.scheduler.elapse(const Duration(seconds: 1));
      });
      await settle(tester, rounds: 3);

      expect(find.text(l10n.netNoticeClosedTitle), findsOneWidget);
      expect(find.text(l10n.netNoticeOnlineClosedText), findsOneWidget);
    });

    for (final width in _widths) {
      testWidgets('ширина ${width.toInt()}: код одной строкой, кнопки на экране', (tester) async {
        final host = await hosted(tester);
        final code = (await tester.runAsync(() => online.codeOf(online.hostActive)))!.code;
        await pumpRoom(tester, host, width: width, height: 568);

        expect(tester.takeException(), isNull);
        final shown = find.ancestor(of: find.text(code.formatted), matching: find.byType(FittedBox));
        expect(tester.getSize(shown).width, lessThanOrEqualTo(width - 2 * 28 - 2 * 20));
        final cancel = find.widgetWithText(GwentButton, l10n.dialogCancel);
        expect(tester.getBottomLeft(cancel).dy, lessThanOrEqualTo(568));
        expect(tester.getTopLeft(find.widgetWithText(GwentButton, l10n.netOnlineCodeCopy)).dx, greaterThanOrEqualTo(0));
      });
    }
  });
}
