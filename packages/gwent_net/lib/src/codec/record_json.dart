import 'package:gwent_net/src/codec/common_json.dart';
import 'package:gwent_net/src/codec/intent_json.dart';
import 'package:gwent_net/src/codec/json_reader.dart';
import 'package:gwent_net/src/journal/match_record.dart';

/// JSON журнала партии: для файла на диске хоста и баг-репортов.
Map<String, Object?> encodeMatchRecord(MatchRecord record) => {
  'match': record.matchId,
  'ruleset': encodeRuleset(record.ruleset),
  'seed': record.seed,
  'one': encodeDeck(record.one),
  'two': encodeDeck(record.two),
  'moves': [
    for (final move in record.moves) {'seat': move.seat.wire, 'intent': encodeIntent(move.intent)},
  ],
};

/// Журнал из JSON; ошибки формата — `MalformedFrame` с путём к полю.
MatchRecord decodeMatchRecord(Object? json) {
  final r = JsonReader(json, r'$');
  return MatchRecord(
    matchId: r.string('match'),
    ruleset: decodeRuleset(r.object('ruleset')),
    seed: r.integer('seed'),
    one: decodeDeck(r.object('one')),
    two: decodeDeck(r.object('two')),
    moves: r.objects('moves', (move) => RecordedMove(decodeSeat(move, 'seat'), decodeIntent(move.object('intent')))),
  );
}
