import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/codec/common_json.dart';
import 'package:gwent_net/src/codec/json_reader.dart';
import 'package:gwent_net/src/codec/protocol_exception.dart';

/// JSON намерения игрока (раздел 3.2 сетевой спецификации).
Map<String, Object?> encodeIntent(Intent intent) => switch (intent) {
  RedrawCard(:final card) => {typeKey: 'redraw', 'card': card.value},
  FinishRedraw() => {typeKey: 'redraw_done'},
  PlayCard(:final card, :final row, :final target) => {
    typeKey: 'play_card',
    'card': card.value,
    'row': ?row?.wire,
    'target': ?target?.value,
  },
  UseLeader() => {typeKey: 'use_leader'},
  Pass() => {typeKey: 'pass'},
  ChooseOption(:final option) => {typeKey: 'choice', 'option': encodeOption(option)},
  Resign() => {typeKey: 'resign'},
};

Intent decodeIntent(JsonReader r) => switch (r.string(typeKey)) {
  'redraw' => RedrawCard(CardInstanceId(r.integer('card'))),
  'redraw_done' => const FinishRedraw(),
  'play_card' => PlayCard(
    CardInstanceId(r.integer('card')),
    row: r.has('row') ? decodeRow(r, 'row') : null,
    target: r.has('target') ? CardInstanceId(r.integer('target')) : null,
  ),
  'use_leader' => const UseLeader(),
  'pass' => const Pass(),
  'choice' => ChooseOption(decodeOption(r.object('option'))),
  'resign' => const Resign(),
  final other => throw MalformedFrame('${r.path}.$typeKey: неизвестное намерение «$other»'),
};
