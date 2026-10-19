/// Сетевой слой Гвинта без реального транспорта (раздел 9, шаг 2 сетевой спецификации).
///
/// Протокол сообщений и его JSON-кодек, хост и клиент партии, нумерация и переотправка сообщений,
/// переподключение по токену, журнал ходов и транспорт в памяти. Чистый Dart: тот же код запустит сервер.
/// Решения описаны в `docs/adr/0005-network-protocol.md`.
library;

export 'src/client/client_event.dart';
export 'src/client/client_settings.dart';
export 'src/client/match_client.dart';
export 'src/client/resume_ticket.dart';
export 'src/codec/envelope_codec.dart';
export 'src/codec/protocol_exception.dart';
export 'src/codec/record_json.dart';
export 'src/entropy/entropy.dart';
export 'src/entropy/secure_entropy.dart';
export 'src/host/host_settings.dart';
export 'src/host/match_host.dart';
export 'src/host/pending_guest.dart';
export 'src/journal/match_journal.dart';
export 'src/journal/match_record.dart';
export 'src/protocol/display_name.dart';
export 'src/protocol/envelope.dart';
export 'src/protocol/net_message.dart';
export 'src/protocol/protocol_version.dart';
export 'src/protocol/ruleset.dart';
export 'src/time/scheduler.dart';
export 'src/transport/in_memory_transport.dart';
export 'src/transport/transport.dart';
