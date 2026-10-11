/// Что умеет движок правил, с которым приложение собрано.
///
/// Пакет контента не зависит от движка: приложение передаёт эти данные в загрузчик из точки сборки.
final class EngineCapabilities {
  /// Создаёт описание движка версии [engineVersion], который реализует эффекты [knownEffects].
  const EngineCapabilities({required this.engineVersion, required this.knownEffects});

  /// Версия движка. Пакет с `min_engine_version` выше неё несовместим.
  final int engineVersion;

  /// Машинные ключи эффектов (`EffectKey.key`), которые движок реализует.
  final Set<String> knownEffects;
}
