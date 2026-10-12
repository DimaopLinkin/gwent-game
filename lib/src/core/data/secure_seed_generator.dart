import 'dart:math';

import 'package:gwent/src/core/domain/seed_generator.dart';

/// Сиды из криптографически стойкого генератора платформы.
final class SecureSeedGenerator implements SeedGenerator {
  /// Создаёт генератор.
  SecureSeedGenerator() : _random = Random.secure();

  final Random _random;

  /// `Random.nextInt` принимает максимум 2^32, поэтому сид собирается из двух половин.
  static const int _half = 0x100000000;

  @override
  int next() => _random.nextInt(_half) << 32 | _random.nextInt(_half);
}
