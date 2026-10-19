import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:meta/meta.dart';

/// Партия, найденная поиском: что объявил хост и куда подключаться.
@immutable
final class FoundGame {
  /// Создаёт найденную партию.
  const FoundGame({required this.ad, required this.address});

  /// Объявление хоста.
  final GameAd ad;

  /// Адрес для подключения.
  final GameAddress address;

  @override
  bool operator ==(Object other) => other is FoundGame && other.ad == ad && other.address == address;

  @override
  int get hashCode => Object.hash(ad, address);

  @override
  String toString() => 'FoundGame($ad, $address)';
}
