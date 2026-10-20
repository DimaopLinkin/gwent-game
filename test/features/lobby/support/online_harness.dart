import 'dart:async';

import 'package:flutter/services.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/link_timings.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/data/online/online_lobby.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/fakes.dart';
import 'fake_online_server.dart';

/// Игра через интернет для тестов экранов: настоящие сценарии и `OnlineLobby` над сервером комнат в памяти.
///
/// У каждого телефона свой вход на сервер: `host` и `guest`; [phone] даёт ещё одного игрока.
final class OnlineHarness {
  /// Собирает стенд. [settings] — настройки, из которых сценарии берут имя игрока.
  OnlineHarness(this.settings) {
    server = FakeOnlineServer(clock);
    hostRooms = server.phone('host');
    guestRooms = server.phone('guest');
    final setup = LoadNetworkSetup(
      LoadGameContent(AssetContentSource.basePack(rootBundle)),
      const FakeAppInfo(),
      WatchSettings(settings),
    );
    hostGame = HostNetworkGame(
      setup,
      OnlineLobby(rooms: hostRooms, scheduler: scheduler, clock: clock),
      hostActive,
      SecureEntropy(),
      scheduler,
      timings: LinkTimings.internet,
      mode: MatchMode.server,
    );
    joinGame = _joinOn(setup, guestRooms, guestActive);
    _setup = setup;
  }

  /// Настройки, из которых берётся имя игрока.
  final InMemorySettingsRepository settings;

  /// Часы стенда.
  final FakeClock clock = FakeClock(DateTime.utc(2026, 10, 20, 12));

  /// Время стенда: сроки связи идут по нему.
  final FakeScheduler scheduler = FakeScheduler();

  /// Игра хоста, ради которой создаются экраны.
  final ActiveNetworkGame hostActive = ActiveNetworkGame();

  /// Игра гостя.
  final ActiveNetworkGame guestActive = ActiveNetworkGame();

  late final FakeOnlineServer server;
  late final FakeOnlineRooms hostRooms;
  late final FakeOnlineRooms guestRooms;
  late final HostNetworkGame hostGame;
  late final JoinNetworkGame joinGame;
  late final LoadNetworkSetup _setup;

  JoinNetworkGame _joinOn(LoadNetworkSetup setup, FakeOnlineRooms rooms, ActiveNetworkGame active) => JoinNetworkGame(
    setup,
    OnlineLobby(rooms: rooms, scheduler: scheduler, clock: clock),
    active,
    scheduler,
    timings: LinkTimings.internet,
    mode: MatchMode.server,
  );

  /// Ещё один игрок со своим входом на сервер.
  JoinNetworkGame phone(String uid) => _joinOn(_setup, server.phone(uid), ActiveNetworkGame());

  /// Пока [done] не завершится, пускает время вперёд: ответ хоста приходит по часам стенда.
  Future<T> elapseUntil<T>(Future<T> done) async {
    final completer = Completer<T>();
    unawaited(done.then(completer.complete, onError: completer.completeError));
    while (!completer.isCompleted) {
      await scheduler.elapse(const Duration(milliseconds: 100));
    }
    return completer.future;
  }

  /// Дожидается, пока обмен сообщениями затихнет.
  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await scheduler.flush();
    }
  }

  /// Закрывает игры обоих телефонов.
  Future<void> close() async {
    await hostActive.current?.close();
    await guestActive.current?.close();
  }

  /// Код комнаты, которую держит хост.
  Future<OnlineAddress> codeOf(ActiveNetworkGame active) async {
    final address = await active.current!.address();
    return address is OnlineAddress ? address : throw StateError('Адрес не онлайн: $address');
  }
}
