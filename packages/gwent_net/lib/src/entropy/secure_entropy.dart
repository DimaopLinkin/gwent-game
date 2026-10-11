import 'dart:math';

import 'package:gwent_net/src/entropy/entropy.dart';

/// Криптографически стойкая случайность платформы (`Random.secure`).
final class SecureEntropy implements Entropy {
  SecureEntropy() : _random = Random.secure();

  final Random _random;

  @override
  int seed() => _random.nextInt(1 << 32) << 20 ^ _random.nextInt(1 << 20);

  @override
  String token() => [for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}
