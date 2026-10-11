import 'dart:async';
import 'dart:typed_data';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Детерминированная «случайность» хоста: сид задан, токены читаемые.
final class FakeEntropy implements Entropy {
  FakeEntropy(this._seed);

  final int _seed;
  int _tokens = 0;

  @override
  int seed() => _seed;

  @override
  String token() => 'token-${_tokens++}';
}

/// Журнал, который сообщает о каждом изменении партии.
final class HookedJournal implements MatchJournal {
  HookedJournal(this.onChange);

  final void Function() onChange;
  final InMemoryMatchJournal _inner = InMemoryMatchJournal();

  MatchRecord? get record => _inner.record;

  @override
  void begin(MatchRecord record) {
    _inner.begin(record);
    onChange();
  }

  @override
  void append(RecordedMove move) {
    _inner.append(move);
    onChange();
  }
}

/// Транспорт, который показывает каждый отправленный кадр.
final class TapTransport implements Transport {
  TapTransport(this._inner, this.onSend);

  final Transport _inner;
  final void Function(Uint8List frame) onSend;

  @override
  Stream<Uint8List> get incoming => _inner.incoming;

  @override
  void send(Uint8List frame) {
    onSend(frame);
    _inner.send(frame);
  }

  @override
  Future<void> close() => _inner.close();
}

/// Партия на столе: хост, клиент хоста и гость на управляемом времени.
///
/// Клиент хоста подключается через `InMemoryTransport` без неполадок, гость — через [FaultyTransport]
/// с неполадками [guestFaults].
final class Table {
  Table({
    int seed = 1,
    this.guestFaults = Faults.none,
    this.faultSeed = 0,
    HostSettings? hostSettings,
    this.onGuestFrame,
    this.onStateChange,
  }) : scheduler = FakeScheduler() {
    journal = HookedJournal(() => onStateChange?.call(host.state!));
    host = MatchHost(
      engine: engine,
      settings: hostSettings ?? const HostSettings(ruleset: ruleset),
      scheduler: scheduler,
      entropy: FakeEntropy(seed),
      journal: journal,
    );
    hostClient = newClient('Хост');
    guest = newClient('Гость');
  }

  final FakeScheduler scheduler;
  final Faults guestFaults;
  final int faultSeed;

  /// Каждый кадр хоста гостю в момент отправки.
  final void Function(Uint8List frame)? onGuestFrame;

  /// Каждое новое состояние партии у хоста.
  final void Function(MatchState state)? onStateChange;

  late final HookedJournal journal;
  late final MatchHost host;
  late final MatchClient hostClient;
  late MatchClient guest;

  /// События каждого клиента по порядку.
  final Map<MatchClient, List<ClientEvent>> events = {};

  /// Переподключать гостя сразу после обрыва (кроме отказа хоста).
  bool autoReconnect = false;

  /// Все соединения гостя со стороны гостя, последнее — текущее.
  final List<FaultyTransport> guestLinks = [];

  FaultyTransport? get guestLink => guestLinks.lastOrNull;

  static const ClientSettings _settings = ClientSettings(ruleset: ruleset, playerName: '', appVersion: 'test');

  MatchClient newClient(String name, {ResumeTicket? ticket, Ruleset clientRuleset = ruleset}) {
    final client = MatchClient(
      settings: ClientSettings(ruleset: clientRuleset, playerName: name, appVersion: _settings.appVersion),
      scheduler: scheduler,
      ticket: ticket,
    );
    final log = events[client] = [];
    client.events.listen((event) {
      log.add(event);
      if (event is ConnectionLost && autoReconnect && client == guest) connectGuest();
    });
    return client;
  }

  /// Подключает клиента хоста.
  void connectHost() {
    final (client, server) = InMemoryTransport.pair();
    host.accept(server);
    hostClient.connect(client);
  }

  /// Подключает гостя (или [client]) новым соединением.
  FaultyTransport connectGuest([MatchClient? client]) {
    final (near, server) = InMemoryTransport.pair();
    final onFrame = onGuestFrame;
    host.accept(onFrame == null ? server : TapTransport(server, onFrame));
    final link = FaultyTransport(
      near,
      scheduler: scheduler,
      faults: guestFaults,
      seed: faultSeed * 1000 + guestLinks.length,
    );
    guestLinks.add(link);
    (client ?? guest).connect(link);
    return link;
  }

  /// Оба подключены, колоды отправлены, партия началась.
  Future<void> start(Deck hostDeck, Deck guestDeck) async {
    connectHost();
    connectGuest();
    hostClient.submitDeck(hostDeck);
    guest.submitDeck(guestDeck);
    await waitFor(() => host.state != null && converged, 'партия не началась');
  }

  /// Продвигает время шагами по 1 с, пока [condition] не выполнится.
  Future<void> waitFor(bool Function() condition, String reason, {int maxSteps = 600}) async {
    await scheduler.flush();
    for (var step = 0; !condition(); step++) {
      if (step >= maxSteps) fail('$reason за $maxSteps с управляемого времени');
      await scheduler.elapse(const Duration(seconds: 1));
    }
  }

  /// Проекции обоих клиентов совпадают с проекциями хоста.
  bool get converged {
    final state = host.state;
    if (state == null) return false;
    for (final client in [hostClient, guest]) {
      final seat = client.seat;
      if (seat == null || client.view != engine.project(state, seat)) return false;
    }
    return true;
  }

  List<T> eventsOf<T extends ClientEvent>(MatchClient client) => events[client]!.whereType<T>().toList();

  /// Доигрывает партию ботами по проекциям клиентов.
  Future<void> playOut({int maxMoves = 2000}) async {
    final bot = ViewBot();
    for (var move = 0; ; move++) {
      await waitFor(() => converged, 'проекции не сошлись');
      if (host.state!.phase == MatchPhase.finished) return;
      if (move >= maxMoves) fail('партия не закончилась за $maxMoves намерений');
      final client = [hostClient, guest].firstWhere(
        (client) => ViewBot.canAct(client.view!),
        orElse: () => fail('никто не может ходить: ${host.state}'),
      );
      await bot.act(this, client);
    }
  }
}

/// Простой бот: строит намерения только по своей проекции и перебирает их, пока хост не примет одно.
final class ViewBot {
  final Map<Seat, int> _salt = {Seat.one: 0, Seat.two: 0};

  static bool canAct(PlayerView view) {
    if (view.outcome != null || view.opponentChoosing != null) return false;
    if (view.choice != null) return true;
    return switch (view.phase) {
      MatchPhase.redraw => !view.me.redrawDone,
      MatchPhase.playing => view.turn == view.viewer,
      MatchPhase.choosingFirstPlayer || MatchPhase.finished => false,
    };
  }

  /// Отправляет намерения клиента по очереди, пока одно не будет принято.
  Future<void> act(Table table, MatchClient client) async {
    final view = client.view!;
    final salt = _salt[view.viewer] = _salt[view.viewer]! + 1;
    final journal = table.journal;
    final queue = candidates(view, salt);
    for (var i = 0; i < queue.length;) {
      final intent = queue[i];
      final moves = journal.record!.moves.length;
      final seq = client.send(intent);
      Refusal? refusal;
      await table.waitFor(() {
        refusal = table
            .eventsOf<ActionRefused>(client)
            .map((event) => event.refusal)
            .where((refusal) => refusal.replyTo == seq)
            .firstOrNull;
        return refusal != null || (journal.record!.moves.length > moves && table.converged);
      }, 'хост не ответил на $intent');
      switch (refusal?.code) {
        case null:
          return;
        case RefusalCode.matchPaused:
          // Соперник переподключается: то же намерение ещё раз, когда он вернётся.
          await table.waitFor(
            () => [table.hostClient, table.guest].every((client) => client.status == ConnectionStatus.online),
            'соперник не вернулся',
          );
        case RefusalCode.intentRejected:
          i++;
        case final code:
          fail('Неожиданный отказ $code на $intent');
      }
    }
    fail('Хост не принял ни одного намерения ${view.viewer}: $view');
  }

  static List<Intent> candidates(PlayerView view, int salt) {
    final choice = view.choice;
    if (choice != null) return [for (final option in _rotate(choice.options, salt)) ChooseOption(option)];
    final me = view.me;
    final hand = me.hand!;
    if (view.phase == MatchPhase.redraw) {
      return [
        if (salt.isEven && hand.isNotEmpty && me.redrawsLeft! > 0) RedrawCard(hand[salt % hand.length].id),
        const FinishRedraw(),
      ];
    }
    final own = [
      for (final row in me.rows.values)
        for (final card in row.cards) card.card.id,
    ];
    final playable = hand.where((card) => me.playable.contains(card.id)).toList();
    return [
      if (salt % 7 == 0 && me.leaderAvailable) const UseLeader(),
      for (final card in _rotate(playable, salt)) ..._plays(card, own),
      const Pass(),
    ];
  }

  static List<Intent> _plays(CardInstance card, List<CardInstanceId> own) {
    final definition = catalog.card(card.cardId);
    if (definition is UnitCardDefinition && definition.placement == UnitPlacement.agile) {
      return [for (final row in definition.placement.rows) PlayCard(card.id, row: row)];
    }
    if (definition is SpecialCardDefinition) {
      final ability = definition.ability;
      if (ability is HornCardAbility || ability is MardremCardAbility) {
        return [for (final row in Row.values) PlayCard(card.id, row: row)];
      }
      if (ability is DecoyAbility) return [for (final target in own) PlayCard(card.id, target: target)];
    }
    return [PlayCard(card.id)];
  }

  static List<T> _rotate<T>(List<T> items, int by) =>
      items.isEmpty ? items : [...items.skip(by % items.length), ...items.take(by % items.length)];
}
