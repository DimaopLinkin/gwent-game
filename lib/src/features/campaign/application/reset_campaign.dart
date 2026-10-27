import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: начать кампанию «Тропа ведьмака» заново (ADR 0033).
///
/// Стирает прогресс по узлам и открытые карты и забывает выбранную колоду кампании. Колоды игрока (в том числе
/// стартовая) и остальные настройки остаются: стартовая колода при новой «Первой партии» записывается поверх той же
/// записью. Игрок, прошедший «Первую партию» раньше, получает стартовый набор при первом входе в тропу
/// (`ClaimStartingSet`), как и новый игрок после «Обучения».
final class ResetCampaign {
  /// Создаёт сценарий.
  const ResetCampaign(this._repository, this._settings);

  final CampaignRepository _repository;
  final SettingsRepository _settings;

  /// Сбрасывает кампанию.
  Future<void> call() async {
    await _repository.reset();
    final settings = await _settings.watch().first;
    if (settings.campaignDeckId != null) await _settings.save(settings.withCampaignDeck(null));
  }
}
