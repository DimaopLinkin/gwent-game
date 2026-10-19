import 'dart:convert';
import 'dart:typed_data';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/codec/common_json.dart';
import 'package:gwent_net/src/codec/event_json.dart';
import 'package:gwent_net/src/codec/intent_json.dart';
import 'package:gwent_net/src/codec/json_reader.dart';
import 'package:gwent_net/src/codec/protocol_exception.dart';
import 'package:gwent_net/src/codec/view_json.dart';
import 'package:gwent_net/src/protocol/envelope.dart';
import 'package:gwent_net/src/protocol/net_message.dart';
import 'package:gwent_net/src/protocol/protocol_version.dart';

/// Кодек кадра: конверт ↔ UTF-8 JSON (раздел 3.1 сетевой спецификации).
///
/// `{"v": 1, "t": "intent", "seq": 42, "ack": 17, "m": "<matchId>", "p": {...}}`.
final class EnvelopeCodec {
  const EnvelopeCodec({this.maxFrameBytes = 64 * 1024});

  /// Кадр больше этого размера отклоняется, не разбираясь.
  final int maxFrameBytes;

  Uint8List encode(Envelope envelope) => utf8.encode(jsonEncode(toJson(envelope)));

  /// Разбирает кадр. Ошибки: [UnsupportedProtocol] для другой версии, [MalformedFrame] для остального.
  Envelope decode(Uint8List frame) {
    if (frame.length > maxFrameBytes) throw MalformedFrame('кадр ${frame.length} байт больше $maxFrameBytes');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(frame));
    } on FormatException catch (error) {
      throw MalformedFrame('не JSON: ${error.message}');
    }
    return fromJson(json);
  }

  Map<String, Object?> toJson(Envelope envelope) => {
    'v': protocolVersion,
    't': _type(envelope.message),
    'seq': envelope.seq,
    'ack': envelope.ack,
    'm': ?envelope.matchId,
    'p': _payload(envelope.message),
  };

  Envelope fromJson(Object? json) {
    final r = JsonReader(json, r'$');
    // Сначала версия: остальной кадр другой версии может быть устроен иначе. Исключение — `reject`,
    // он не меняется между версиями, и его разбирает клиент любой версии.
    final version = r.integer('v');
    if (version != protocolVersion && r.optionalString('t') != 'reject') throw UnsupportedProtocol(version);
    final type = r.string('t');
    final message = _message(type, r.object('p'));
    final seq = r.integer('seq');
    final sequenced = message is! ControlMessage;
    if (sequenced != seq > 0) {
      throw MalformedFrame(
        r'$.seq: '
        '${sequenced ? 'у сообщения «$type» нет номера' : 'у служебного «$type» номер $seq'}',
      );
    }
    final ack = r.integer('ack');
    if (ack < 0) throw const MalformedFrame(r'$.ack: отрицательный');
    return Envelope(message, seq: seq, ack: ack, matchId: r.optionalString('m'));
  }
}

String _type(NetMessage message) => switch (message) {
  Hello() => 'hello',
  Welcome() => 'welcome',
  JoinRejected() => 'reject',
  Ping() => 'ping',
  Pong() => 'pong',
  ResendRequest() => 'resend',
  DeckSubmission() => 'deck_submit',
  IntentMessage() => 'intent',
  MatchUpdate() => 'events',
  MatchSnapshot() => 'snapshot',
  Refusal() => 'error',
  OpponentPresence() => 'opponent',
  LobbyStatus() => 'lobby_status',
  DeckWithdrawal() => 'deck_withdraw',
  LobbyLeave() => 'lobby_leave',
  OpponentLobby() => 'opponent_lobby',
  CountdownStart() => 'countdown_start',
  CountdownCancel() => 'countdown_cancel',
  OpponentLeave() => 'opponent_leave',
  LobbyClose() => 'lobby_close',
};

Map<String, Object?> _payload(NetMessage message) => switch (message) {
  Hello(:final ruleset, :final playerName, :final appVersion, :final resumeToken) => {
    'ruleset': encodeRuleset(ruleset),
    'name': playerName,
    'app': appVersion,
    'resume_token': ?resumeToken,
  },
  Welcome(:final seat, :final matchId, :final resumeToken, :final next) => {
    'seat': seat.wire,
    'match': matchId,
    'resume_token': resumeToken,
    'next': next,
  },
  JoinRejected(:final reason, :final protocol) => {'reason': reason.wire, 'protocol': protocol},
  Ping(:final sent) || Pong(:final sent) => {'sent': sent},
  ResendRequest() => const {},
  DeckSubmission(:final deck) => {'deck': encodeDeck(deck)},
  IntentMessage(:final intent) => {'intent': encodeIntent(intent)},
  MatchUpdate(:final events, :final view) => {
    'events': [for (final event in events) encodeEvent(event)],
    'view': encodeView(view),
  },
  MatchSnapshot(:final view) => {'view': encodeView(view)},
  Refusal(:final code, :final replyTo, :final reject) => {
    'code': code.wire,
    'reply_to': replyTo,
    'reject': ?_encodeOptionalReject(reject),
  },
  OpponentPresence(:final online, :final name) => {'online': online, 'name': name},
  LobbyStatus(:final stage, :final leader) => {'stage': stage.wire, 'leader': ?leader?.value},
  DeckWithdrawal() || LobbyLeave() || CountdownCancel() || OpponentLeave() || LobbyClose() => const {},
  OpponentLobby(:final stage, :final leader) => {'stage': stage.wire, 'leader': ?leader?.value},
  CountdownStart(:final duration) => {'ms': duration.inMilliseconds},
};

NetMessage _message(String type, JsonReader p) => switch (type) {
  'hello' => Hello(
    ruleset: decodeRuleset(p.object('ruleset')),
    playerName: p.string('name'),
    appVersion: p.string('app'),
    resumeToken: p.optionalString('resume_token'),
  ),
  'welcome' => Welcome(
    seat: decodeSeat(p, 'seat'),
    matchId: p.string('match'),
    resumeToken: p.string('resume_token'),
    next: p.integer('next'),
  ),
  'reject' => JoinRejected(p.enumValue('reason', JoinRefusal.values), protocol: p.integer('protocol')),
  'ping' => Ping(sent: p.integer('sent')),
  'pong' => Pong(sent: p.integer('sent')),
  'resend' => const ResendRequest(),
  'deck_submit' => DeckSubmission(decodeDeck(p.object('deck'))),
  'intent' => IntentMessage(decodeIntent(p.object('intent'))),
  'events' => MatchUpdate(p.objects('events', decodeEvent), decodeView(p.object('view'))),
  'snapshot' => MatchSnapshot(decodeView(p.object('view'))),
  'error' => Refusal(
    p.enumValue('code', RefusalCode.values),
    replyTo: p.integer('reply_to'),
    reject: p.optional('reject', decodeReject),
  ),
  'opponent' => OpponentPresence(online: p.boolean('online'), name: p.string('name')),
  'lobby_status' => _lobbyStatus(p),
  'deck_withdraw' => const DeckWithdrawal(),
  'lobby_leave' => const LobbyLeave(),
  'opponent_lobby' => OpponentLobby(p.enumValue('stage', LobbyStage.values), leader: _optionalLeader(p)),
  'countdown_start' => CountdownStart(Duration(milliseconds: p.integer('ms'))),
  'countdown_cancel' => const CountdownCancel(),
  'opponent_leave' => const OpponentLeave(),
  'lobby_close' => const LobbyClose(),
  final other => throw MalformedFrame(
    r'$.t: '
    'неизвестный тип сообщения «$other»',
  ),
};

Map<String, Object?>? _encodeOptionalReject(Reject? reject) => reject == null ? null : encodeReject(reject);

/// Состояние лобби клиента: готовность передаётся колодой, поэтому стадия `ready` здесь — нарушение протокола.
LobbyStatus _lobbyStatus(JsonReader p) {
  final stage = p.enumValue('stage', LobbyStage.values);
  if (stage == LobbyStage.ready) throw MalformedFrame('${p.path}.stage: готовность передаётся колодой');
  return LobbyStatus(stage, leader: _optionalLeader(p));
}

LeaderId? _optionalLeader(JsonReader p) => switch (p.optionalString('leader')) {
  final leader? => LeaderId(leader),
  null => null,
};
