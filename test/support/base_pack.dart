import 'package:flutter/services.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent_content/gwent_content.dart';

/// Базовый пакет контента из ассетов приложения (его собирает `setup.sh`). Движок знает весь формат.
Future<ContentPack> loadBasePack() async {
  final engine = EngineCapabilities(
    engineVersion: 1,
    knownEffects: {for (final effect in EffectKey.values) effect.key},
  );
  final result = await ContentPackLoader(engine: engine).load(AssetContentSource.basePack(rootBundle));
  return switch (result) {
    PackLoaded(:final pack) => pack,
    PackRejected(:final issues) => throw StateError(issues.join('\n')),
  };
}
