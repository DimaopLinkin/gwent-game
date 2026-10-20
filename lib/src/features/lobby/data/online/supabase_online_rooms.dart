import 'dart:async';
import 'dart:convert';

import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/features/lobby/data/online/online_config.dart';
import 'package:gwent/src/features/lobby/data/online/online_rooms.dart';
import 'package:gwent/src/features/lobby/data/online/room_channel.dart';
import 'package:gwent/src/features/lobby/data/online/supabase_room_channel.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/online_session_store.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';
import 'package:gwent_net/gwent_net.dart' show cleanDisplayName;
import 'package:supabase/supabase.dart';

/// Комнаты игры через интернет на Supabase (ADR 0025, 0026).
///
/// Игрок входит анонимно, лениво, при первом обращении к серверу: сессия хранится в [OnlineSessionStore], чтобы не
/// заводить нового игрока на каждый заход. Комнаты создаются и занимаются функциями базы, прямой записи в таблицы нет.
final class SupabaseOnlineRooms implements OnlineRooms {
  /// Создаёт комнаты. Клиент Supabase создаётся при первом обращении; [client] подставляют тесты.
  SupabaseOnlineRooms({
    required OnlineConfig config,
    required OnlineSessionStore sessions,
    required Clock clock,
    SupabaseClient? client,
    this.requestTimeout = const Duration(seconds: 10),
    this.channelTimeout = const Duration(seconds: 10),
  }) : _config = config,
       _sessions = sessions,
       _clock = clock,
       _injected = client;

  /// Сколько ждать ответа сервера на запрос. Спящий бесплатный проект не отвечает, а не отказывает.
  final Duration requestTimeout;

  /// Сколько ждать подтверждения входа в канал.
  final Duration channelTimeout;

  final OnlineConfig _config;
  final OnlineSessionStore _sessions;
  final Clock _clock;
  final SupabaseClient? _injected;

  bool _created = false;

  late final SupabaseClient _client = _build();

  SupabaseClient _build() {
    final injected = _injected;
    if (injected != null) return injected;
    _created = true;
    return SupabaseClient(
      _config.url,
      _config.publishableKey,
      // Анонимному входу PKCE не нужен, поэтому и его хранилища нет (оно по умолчанию в shared_preferences).
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
  }

  Future<void>? _signingIn;
  StreamSubscription<AuthState>? _authEvents;

  /// Отписывается от событий входа и закрывает клиент, если он был создан. Приложение живёт столько же, сколько
  /// процесс, и не вызывает этот метод; он нужен тестам.
  Future<void> dispose() async {
    await _authEvents?.cancel();
    _authEvents = null;
    if (_created) await _client.dispose();
  }

  @override
  Future<RoomInfo> create(GameAd ad) async {
    final reply = await _call('create_room', {
      'p_host_name': _serverName(ad.hostName),
      'p_protocol': ad.protocol,
      'p_ruleset_id': ad.ruleset.id,
      'p_ruleset_hash': ad.ruleset.hash,
      'p_engine_version': ad.ruleset.engineVersion,
    });
    return _room(reply);
  }

  @override
  Future<RoomInfo> join(RoomCode code) async => _room(await _call('join_room', {'p_code': code.value}));

  @override
  Future<void> setOpen(String roomId, {required bool open}) async {
    await _call('set_room_open', {'p_room_id': roomId, 'p_open': open});
  }

  @override
  Future<void> close(String roomId) async {
    await _call('close_room', {'p_room_id': roomId});
  }

  @override
  Future<RoomStanding> standing(String roomId) async {
    await _ensureSession();
    final Map<String, dynamic>? row;
    try {
      row = await _client
          .from('rooms')
          .select('closed_at, expires_at')
          .eq('id', roomId)
          .maybeSingle()
          .timeout(requestTimeout);
    } on Exception catch (error) {
      throw await _unavailable(error);
    }
    final expiresAt = DateTime.tryParse('${row?['expires_at']}')?.toUtc();
    if (row == null || row['closed_at'] != null || expiresAt == null || !expiresAt.isAfter(_clock.now())) {
      return const RoomGone();
    }
    return RoomAlive(expiresAt);
  }

  @override
  Future<RoomChannel> connect(String roomId) async {
    final session = await _ensureSession();
    try {
      // Приватный канал проверяет доступ по токену игрока: он должен быть у Realtime до входа.
      await _client.realtime.setAuth(session.accessToken);
      return await SupabaseRoomChannel.join(_client, roomId, timeout: channelTimeout);
    } on LobbyException {
      rethrow;
    } on Exception catch (error) {
      throw LobbyException(LobbyFailure.unavailable, error);
    }
  }

  /// Имя хоста в виде, который принимает база: без невидимых знаков (в том числе соединителя нулевой ширины, который
  /// оставляет `cleanDisplayName`) и не длиннее 64 знаков. Пустое имя заменяется прочерком.
  static String _serverName(String name) {
    final clean = String.fromCharCodes(cleanDisplayName(name).runes.where((rune) => rune != 0x200d)).trim();
    final limited = String.fromCharCodes(clean.runes.take(64)).trim();
    return limited.isEmpty ? '-' : limited;
  }

  Future<Map<String, dynamic>> _call(String function, Map<String, dynamic> params) async {
    await _ensureSession();
    final Object? reply;
    try {
      reply = await _client.rpc<dynamic>(function, params: params).timeout(requestTimeout);
    } on Exception catch (error) {
      throw await _unavailable(error);
    }
    if (reply is! Map<String, dynamic>) throw LobbyException(LobbyFailure.unavailable, 'Ответ не объект: $reply');
    if (reply['ok'] == true) return reply;
    throw LobbyException(_refusal('${reply['reason']}'), reply['reason']);
  }

  static LobbyFailure _refusal(String reason) => switch (reason) {
    'not_found' => LobbyFailure.codeNotFound,
    'full' => LobbyFailure.roomFull,
    'closed' => LobbyFailure.roomClosed,
    'own_room' => LobbyFailure.ownRoom,
    'too_many_attempts' => LobbyFailure.tooManyAttempts,
    'too_many_rooms' => LobbyFailure.tooManyRooms,
    _ => LobbyFailure.unavailable,
  };

  RoomInfo _room(Map<String, dynamic> reply) {
    try {
      final room = reply['room'] as Map<String, dynamic>;
      return RoomInfo(
        id: room['id'] as String,
        code: RoomCode.tryParse(room['code'] as String) ?? (throw const FormatException('Код комнаты')),
        hostName: room['host_name'] as String,
        protocol: room['protocol'] as int,
        rulesetId: room['ruleset_id'] as String,
        rulesetHash: room['ruleset_hash'] as String,
        engineVersion: room['engine_version'] as int,
        open: room['open'] as bool,
        expiresAt: DateTime.parse(room['expires_at'] as String).toUtc(),
      );
    } on FormatException catch (error) {
      throw LobbyException(LobbyFailure.unavailable, error);
    } on TypeError catch (error) {
      // Ответ сервера не по контракту ADR 0025: считаем сервис неисправным, а не роняем приложение.
      throw LobbyException(LobbyFailure.unavailable, error);
    }
  }

  /// Сбой сервиса: нет сети, проект не ответил, вход отклонён. Если сервер сказал, что сессия не годится, она
  /// обновляется, а если и это не вышло, забывается: следующая попытка войдёт заново.
  Future<LobbyException> _unavailable(Exception error) async {
    final rejected = switch (error) {
      PostgrestException(:final code) => code == '28000' || code == 'PGRST301' || code == 'PGRST303',
      _ => false,
    };
    if (rejected) await _refreshOrForget();
    return LobbyException(LobbyFailure.unavailable, error);
  }

  /// Сервер не принял токен: сначала он обновляется, чтобы игрок остался тем же (иначе он потеряет свою комнату), и
  /// только если обновить не вышло, сессия забывается и игрок входит заново.
  Future<void> _refreshOrForget() async {
    try {
      await _client.auth.refreshSession();
    } on Exception {
      await _forgetSession();
    }
  }

  /// Сессия игрока: сохранённая, а если её нет или она не годится, то новый анонимный вход.
  Future<Session> _ensureSession() async {
    await (_signingIn ??= _signIn().whenComplete(() => _signingIn = null));
    final session = _client.auth.currentSession;
    if (session == null) throw const LobbyException(LobbyFailure.unavailable, 'Вход не выполнен');
    return session;
  }

  Future<void> _signIn() async {
    final auth = _client.auth;
    _authEvents ??= auth.onAuthStateChange.listen(
      _remember,
      onError: (Object _) {
        // Ошибка обновления сессии придёт и тому, кто сделает следующий запрос: здесь сохранять нечего.
      },
    );
    try {
      if (auth.currentSession == null) {
        final stored = await _sessions.read();
        if (stored != null) await _recover(auth, stored);
      }
      if (auth.currentSession?.isExpired ?? false) await auth.refreshSession();
      if (auth.currentSession == null) await auth.signInAnonymously();
    } on Exception catch (error) {
      throw LobbyException(LobbyFailure.unavailable, error);
    }
  }

  Future<void> _recover(GoTrueClient auth, String stored) async {
    try {
      await auth.recoverSession(stored);
    } on Object {
      // Сессия повреждена, просрочена или игрока уже нет на сервере: она не нужна, игрок войдёт заново.
      await _sessions.clear();
    }
  }

  Future<void> _forgetSession() async {
    try {
      await _client.auth.signOut();
    } on Exception {
      // Сервер недоступен: локально сессия всё равно забыта.
      return;
    }
  }

  void _remember(AuthState state) {
    final session = state.session;
    final Future<void> saved;
    switch (state.event) {
      case AuthChangeEvent.signedIn || AuthChangeEvent.tokenRefreshed || AuthChangeEvent.initialSession:
        if (session == null) return;
        saved = _sessions.write(jsonEncode(session.toJson()));
      case AuthChangeEvent.signedOut:
        saved = _sessions.clear();
      case _:
        return;
    }
    unawaited(
      saved.then<void>(
        (_) {},
        onError: (Object _) {
          // Не записали: игрок войдёт заново при следующем запуске, это не мешает игре.
        },
      ),
    );
  }
}
