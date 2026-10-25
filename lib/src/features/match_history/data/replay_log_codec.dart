import 'dart:convert';

import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;
import 'package:gwent_net/gwent_net.dart' as net;

/// Запись реплея в виде, в каком она лежит в базе: вид, версия формата и текст JSON.
typedef EncodedReplay = ({String perspective, String kind, int formatVersion, String payload});

/// Кодек реплеев для базы.
///
/// Вид записи и перспектива хранятся стабильными кодами, а не именами значений: переименование в домене не трогает
/// данные. Новый вид записи получает новый код; формат вида меняется только с новой версией формата, старые
/// версии читаются всегда.
final class ReplayLogCodec {
  /// Создаёт кодек.
  const ReplayLogCodec();

  static const String _journal = 'journal';
  static const int _journalFormat = 1;
  // Кадры лежат в проводном формате проекции и события (`gwent_net`): изменение этого формата повышает
  // `_framesFormat`, а чтение старой версии остаётся (ADR 0029).
  static const String _frames = 'frames';
  static const int _framesFormat = 1;

  static String _seatCode(Seat seat) => switch (seat) {
    Seat.one => 'one',
    Seat.two => 'two',
  };

  /// Записывает [log] для базы.
  EncodedReplay encode(ReplayLog log) => switch (log) {
    JournalReplayLog(:final journal, :final perspective) => (
      perspective: _seatCode(perspective),
      kind: _journal,
      formatVersion: _journalFormat,
      payload: jsonEncode(net.encodeMatchRecord(journal)),
    ),
    FramesReplayLog(:final frames, :final ruleset, :final perspective) => (
      perspective: _seatCode(perspective),
      kind: _frames,
      formatVersion: _framesFormat,
      payload: jsonEncode({
        'ruleset': {'id': ruleset.id, 'hash': ruleset.hash, 'engine': ruleset.engineVersion},
        'frames': [for (final frame in frames) net.encodeViewFrame(frame)],
      }),
    ),
  };

  /// Читает запись из базы. Бросает [ReplayCorrupted], если запись повреждена или записана неизвестным форматом.
  ReplayLog decode(EncodedReplay encoded) {
    final perspective = switch (encoded.perspective) {
      'one' => Seat.one,
      'two' => Seat.two,
      final code => throw ReplayCorrupted('неизвестное место $code'),
    };
    switch (encoded.kind) {
      case _journal:
        if (encoded.formatVersion != _journalFormat) {
          throw ReplayCorrupted('журнал формата ${encoded.formatVersion} не поддерживается');
        }
        try {
          return JournalReplayLog(
            net.decodeMatchRecord(jsonDecode(encoded.payload)),
            perspective: perspective,
          );
        } on FormatException catch (error) {
          throw ReplayCorrupted('журнал не читается: ${error.message}');
        } on net.ProtocolException catch (error) {
          throw ReplayCorrupted('журнал не читается: ${error.message}');
        }
      case _frames:
        if (encoded.formatVersion != _framesFormat) {
          throw ReplayCorrupted('кадры формата ${encoded.formatVersion} не поддерживаются');
        }
        try {
          return _decodeFrames(jsonDecode(encoded.payload), perspective);
        } on FormatException catch (error) {
          throw ReplayCorrupted('кадры не читаются: ${error.message}');
        } on net.ProtocolException catch (error) {
          throw ReplayCorrupted('кадры не читаются: ${error.message}');
        }
      default:
        throw ReplayCorrupted('неизвестный вид записи ${encoded.kind}');
    }
  }

  FramesReplayLog _decodeFrames(Object? json, Seat perspective) {
    if (json is! Map<String, Object?>) throw const FormatException('ожидался объект');
    final ruleset = json['ruleset'];
    final frames = json['frames'];
    if (ruleset is! Map<String, Object?> || frames is! List<Object?> || frames.isEmpty) {
      throw const FormatException('нет набора правил или кадров');
    }
    final id = ruleset['id'];
    final hash = ruleset['hash'];
    final engine = ruleset['engine'];
    if (id is! String || hash is! String || engine is! int) throw const FormatException('набор правил не читается');
    return FramesReplayLog(
      [for (final frame in frames) net.decodeViewFrame(frame)],
      ruleset: net.Ruleset(id: id, hash: hash, engineVersion: engine),
      perspective: perspective,
    );
  }
}
