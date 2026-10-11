import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:uuid/uuid.dart';

/// Идентификаторы UUID v4: уникальны без координации, поэтому годятся и для обмена колодами между устройствами.
final class UuidIdGenerator implements IdGenerator {
  /// Создаёт генератор.
  const UuidIdGenerator();

  static const Uuid _uuid = Uuid();

  @override
  String next() => _uuid.v4();
}
