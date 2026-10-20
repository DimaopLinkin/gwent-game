import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_invite.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/presentation/host_invite_state.dart';

/// Держатель экрана с QR-кодом партии (макет 9, экран 2c): готовит приглашение и сообщает, когда код больше не нужен.
final class HostInviteCubit extends Cubit<HostInviteState> {
  /// Создаёт держатель и сразу узнаёт адрес партии [game].
  HostInviteCubit(this._game) : super(const HostInviteLoading()) {
    _subscription = _game.rooms.listen(_onRoom);
    // Соперник мог подключиться, пока открывался экран: поток `rooms` отдаёт только новое.
    if (_hasOpponentOrEnd(_game.room)) {
      emit(const HostInviteDone());
    } else {
      unawaited(_load());
    }
  }

  final NetworkGame _game;
  StreamSubscription<LobbyRoom>? _subscription;

  Future<void> _load() async {
    final GameAddress? address;
    try {
      address = await _game.address();
    } on Object catch (error, stackTrace) {
      // Адрес не узнать (нет сетевых интерфейсов, партия закрыта): код показать нечем.
      addError(error, stackTrace);
      if (!isClosed && state is HostInviteLoading) emit(const HostInviteFailed());
      return;
    }
    if (isClosed || state is! HostInviteLoading) return;
    emit(address == null ? const HostInviteFailed() : HostInviteReady(GameInvite.encode(address), _label(address)));
  }

  bool _hasOpponentOrEnd(LobbyRoom room) =>
      room.opponent != null || room.pendingGuest != null || room.end != null || room.started;

  void _onRoom(LobbyRoom room) {
    if (_hasOpponentOrEnd(room)) emit(const HostInviteDone());
  }

  /// Адрес для людей: первый адрес хоста и порт, IPv6 в скобках.
  String _label(GameAddress address) => switch (address) {
    LanAddress(:final hosts, :final port) => '${hosts.first.contains(':') ? '[${hosts.first}]' : hosts.first}:$port',
    OnlineAddress(:final code) => code.formatted,
  };

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
