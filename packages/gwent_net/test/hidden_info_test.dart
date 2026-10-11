import 'dart:convert';
import 'dart:typed_data';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Скрытость (раздел 8, пункт 4 сетевой спецификации): в трафике хоста гостю нет карт руки и колоды хоста,
/// пока они не открылись.
void main() {
  for (final (index, (hostDeck, guestDeck)) in [(nilfgaardReveal, skellige), ...pairings].indexed) {
    test('гость ${guestDeck.leader.value} не видит скрытых карт хоста ${hostDeck.leader.value}', () async {
      late final Table table;
      final inspector = HiddenCardInspector(host: Seat.one);
      table = Table(
        seed: index + 11,
        onStateChange: inspector.remember,
        onGuestFrame: (frame) => inspector.inspect(frame, table.host.state),
      );
      await table.start(hostDeck, guestDeck);
      // Обрыв в пересдаче: хост досылает пропущенное.
      await table.guestLink!.cut();
      table.connectGuest();
      final bot = ViewBot();
      while (table.host.state!.phase != MatchPhase.playing || table.journal.record!.moves.length < 8) {
        await table.waitFor(() => table.converged, 'проекции не сошлись');
        await bot.act(table, [table.hostClient, table.guest].firstWhere((client) => ViewBot.canAct(client.view!)));
      }
      // Перезапуск гостя посреди раунда: хост отдаёт снимок.
      final ticket = table.guest.ticket!;
      await table.guestLink!.cut();
      await table.guest.close();
      table.guest = table.newClient('Гость', ticket: ticket);
      final snapshots = inspector.snapshots;
      table.connectGuest();
      await table.playOut();
      expect(inspector.snapshots, snapshots + 1, reason: 'снимок прошёл через проверку');

      expect(inspector.violations, isEmpty);
      if (hostDeck == nilfgaardReveal) {
        List<HandRevealed> reveals(MatchClient client) =>
            table.eventsOf<ViewChanged>(client).expand((event) => event.events).whereType<HandRevealed>().toList();
        expect(reveals(table.hostClient), isNotEmpty, reason: 'Эмгыр показал хосту руку гостя');
        expect(reveals(table.guest), isEmpty);
      }
      expect(inspector.frames, greaterThan(20));
      expect(inspector.cardsChecked, greaterThan(0), reason: 'в трафике были карты, проверка не пустая');
    });
  }

  test('проверка ловит утечку: взятые хостом карты в чужом кадре', () async {
    final table = Table();
    await table.start(skellige, northern);
    final state = table.host.state!;
    final inspector = HiddenCardInspector(host: Seat.one)..remember(state);
    final hand = state.player(Seat.one).hand;
    final leak = const EnvelopeCodec().encode(
      Envelope(MatchUpdate([CardsDrawn(Seat.one, hand)], engine.project(state, Seat.two)), seq: 9),
    );
    inspector.inspect(leak, state);
    expect(inspector.violations, isNotEmpty);
  });
}

/// Проверяет кадры гостю: ни одна скрытая карта хоста (рука, колода, никогда не открывавшаяся) не попадает
/// в них ни экземпляром (номер вместе с картой), ни идентификатором карты. Голый номер экземпляра не проверяется:
/// номера — случайная перестановка (ADR 0001), без карты они ничего не говорят.
final class HiddenCardInspector {
  HiddenCardInspector({required this.host});

  final Seat host;
  final Set<CardInstance> _everPublic = {};
  final Set<CardId> _guestCards = {};
  final List<String> violations = [];
  int frames = 0;
  int snapshots = 0;
  int cardsChecked = 0;

  /// Запоминает открытые карты состояния: поле, слоты рогов, отбои, погода.
  void remember(MatchState state) {
    for (final seat in Seat.values) {
      final player = state.player(seat);
      _everPublic.addAll(player.discard);
      for (final row in player.rows.values) {
        for (final card in row.cards) {
          _everPublic.addAll([card.card, ?card.beneath]);
        }
        if (row.slot case CardSlot(:final card)) _everPublic.add(card);
      }
    }
    _everPublic.addAll(state.weather.map((weather) => weather.card));
    final guest = state.player(host.opponent);
    _guestCards.addAll([...guest.deck, ...guest.hand, ...guest.discard].map((card) => card.cardId));
  }

  void inspect(Uint8List frame, MatchState? state) {
    frames++;
    if (state == null) return;
    remember(state);
    final player = state.player(host);
    final hidden = {...player.hand, ...player.deck}.difference(_everPublic);
    final shownIds = {..._everPublic.map((card) => card.cardId), ..._guestCards};
    final text = utf8.decode(frame);
    final json = jsonDecode(text);
    if (json case {'t': 'snapshot'}) snapshots++;
    for (final card in _cards(json)) {
      cardsChecked++;
      if (hidden.contains(card)) violations.add('экземпляр $card в кадре $text');
    }
    for (final card in hidden) {
      if (!shownIds.contains(card.cardId) && text.contains('"${card.cardId.value}"')) {
        violations.add('карта ${card.cardId.value} в кадре $text');
      }
    }
  }

  /// Все экземпляры карт в JSON: объекты ровно с полями `id` и `card`.
  Iterable<CardInstance> _cards(Object? json) sync* {
    if (json is Map<String, Object?>) {
      if (json case {'id': final int id, 'card': final String card} when json.length == 2) {
        yield CardInstance(CardInstanceId(id), CardId(card));
      }
      for (final value in json.values) {
        yield* _cards(value);
      }
    } else if (json is List<Object?>) {
      for (final value in json) {
        yield* _cards(value);
      }
    }
  }
}
