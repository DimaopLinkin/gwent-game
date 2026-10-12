import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Объявление и поиск сервисов в локальной сети (DNS-SD поверх mDNS, Bonjour).
///
/// Отделяет лобби от плагина платформы: в тестах подставляется фейк, на телефоне — `BonsoirServiceDirectory`.
abstract interface class ServiceDirectory {
  /// Объявляет сервис. Бросает `LobbyException` (`unavailable`), если служба ОС отказала.
  Future<ServiceAdvertisement> advertise(ServiceRecord record);

  /// Поиск сервисов: подписка запускает поиск, отмена останавливает. Сервисы приходят уже с адресами.
  /// Отказ службы ОС приходит ошибкой `LobbyException` (`unavailable`), после неё поток закрывается.
  Stream<DirectoryEvent> browse();
}

/// Действующее объявление сервиса.
abstract interface class ServiceAdvertisement {
  /// Снимает объявление.
  Future<void> stop();
}

/// Сервис в сети: имя экземпляра, порт, TXT-запись и, у найденного, адреса хоста.
@immutable
final class ServiceRecord {
  /// Создаёт запись.
  ServiceRecord({
    required this.name,
    required this.port,
    required Map<String, String> attributes,
    List<String> hosts = const [],
  }) : attributes = Map.unmodifiable(attributes),
       hosts = List.unmodifiable(hosts);

  /// Имя экземпляра сервиса. ОС может переименовать его при совпадении с чужим.
  final String name;

  /// Порт.
  final int port;

  /// TXT-запись: короткие пары ключ–значение.
  final Map<String, String> attributes;

  /// IP-адреса хоста; у объявляемой записи пусто.
  final List<String> hosts;

  @override
  bool operator ==(Object other) =>
      other is ServiceRecord &&
      other.name == name &&
      other.port == port &&
      const MapEquality<String, String>().equals(other.attributes, attributes) &&
      const ListEquality<String>().equals(other.hosts, hosts);

  @override
  int get hashCode => Object.hash(
    name,
    port,
    Object.hashAllUnordered(attributes.entries.map((e) => (e.key, e.value))),
    Object.hashAll(hosts),
  );

  @override
  String toString() => 'ServiceRecord($name, $port, $attributes, $hosts)';
}

/// Событие поиска.
@immutable
sealed class DirectoryEvent {
  const DirectoryEvent();
}

/// Сервис найден или изменился (новая TXT-запись или адреса).
final class ServiceFound extends DirectoryEvent {
  /// Создаёт событие.
  const ServiceFound(this.record);

  /// Сервис с адресами.
  final ServiceRecord record;

  @override
  bool operator ==(Object other) => other is ServiceFound && other.record == record;

  @override
  int get hashCode => record.hashCode;
}

/// Сервис пропал из сети.
final class ServiceLost extends DirectoryEvent {
  /// Создаёт событие.
  const ServiceLost(this.name);

  /// Имя экземпляра сервиса.
  final String name;

  @override
  bool operator ==(Object other) => other is ServiceLost && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
