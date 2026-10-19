import 'package:gwent/src/features/lobby/domain/found_game.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent_net/gwent_net.dart';

/// Лобби сетевой игры: хост объявляет партию и принимает соединения, гость находит партию и подключается
/// (раздел 6 сетевой спецификации).
///
/// Лобби только связывает телефоны: каждое соединение — это `Transport` протокола `gwent_net`, его получает
/// `MatchHost.accept` у хоста и `MatchClient.connect` у гостя. Реализации: Wi-Fi (mDNS + WebSocket), позже BLE.
abstract interface class GameLobby {
  /// Начинает принимать соединения и объявляет партию [ad].
  ///
  /// Бросает [LobbyException] с `LobbyFailure.unavailable`, если объявить партию нельзя.
  Future<HostedGame> host(GameAd ad);

  /// Ищет объявленные партии. Каждое значение — полный список найденного сейчас, первое — пустой список.
  ///
  /// Подписка запускает поиск, отмена подписки останавливает. Отказ службы поиска приходит ошибкой
  /// [LobbyException] с `LobbyFailure.unavailable`, после неё поток закрывается.
  Stream<List<FoundGame>> discover();

  /// Подключается к партии по адресу из поиска или из приглашения.
  ///
  /// Бросает [LobbyException] с `LobbyFailure.unreachable`, если хост недоступен.
  Future<Transport> join(GameAddress address);
}

/// Партия, которую проводит этот телефон.
abstract interface class HostedGame {
  /// Текущее объявление.
  GameAd get ad;

  /// Входящие соединения по порядку. Поток закрывается после [close] или если ОС закрыла приём
  /// (на iOS при сворачивании). Во втором случае объявление тоже снимается, а партию объявляют заново через
  /// `GameLobby.host` с тем же идентификатором. Отмена подписки на поток закрывает партию, как [close].
  Stream<Transport> get connections;

  /// Адрес для приглашения без поиска (QR-код).
  Future<GameAddress> address();

  /// Заменяет объявление, например закрывает его после начала партии. Идентификатор менять нельзя.
  /// Вызовы выполняются по очереди.
  ///
  /// Бросает [LobbyException] с `LobbyFailure.unavailable`, если объявить заново не удалось, и [StateError],
  /// если партия закрыта.
  Future<void> advertise(GameAd ad);

  /// Снимает объявление и перестаёт принимать соединения. Уже принятые соединения остаются открытыми:
  /// ими владеет хост партии.
  Future<void> close();
}
