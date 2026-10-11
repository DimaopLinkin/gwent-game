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
    final type = r.string('t');
    final version = r.integer('v');
    // `reject` не меняется между версиями: его разбирает клиент любой версии.
    if (version != protocolVersion && type != 'reject') throw UnsupportedProtocol(version);
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
};

Map<String, Object?> _payload(NetMessage message) => switch (message) {
  Hello(:final ruleset, :final playerName, :final appVersion, :final resumeToken) => {
    'ruleset': encodeRuleset(ruleset),
    'name': playerName,
    'app': appVersion,
    'resume_token': ?resumeToken,
  },
  Welcome(:final seat, :final matchId, :final resumeToken, :final next) => {
    'seat': seat.name,
    'match': matchId,
    'resume_token': resumeToken,
    'next': next,
  },
  JoinRejected(:final reason, :final protocol) => {'reason': reason.name, 'protocol': protocol},
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
    'code': code.name,
    'reply_to': replyTo,
    'reject': ?_encodeOptionalReject(reject),
  },
  OpponentPresence(:final online) => {'online': online},
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
  'opponent' => OpponentPresence(online: p.boolean('online')),
  final other => throw MalformedFrame(
    r'$.t: '
    'неизвестный тип сообщения «$other»',
  ),
};

Map<String, Object?>? _encodeOptionalReject(Reject? reject) => reject == null ? null : encodeReject(reject);
