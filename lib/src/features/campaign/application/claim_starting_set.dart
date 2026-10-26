import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: выдать стартовый набор тому, кто прошёл «Первую партию» раньше, в «Обучении» (ADR 0033, ADR 0034).
///
/// Миссия 0 кампании это та же «Первая партия». Кто прошёл её до кампании, при первом входе в кампанию получает
/// набор без второго прохождения, а узел 0 помечается пройденным. Кто проходит её из кампании, получает набор
/// теми же шагами: партия отмечает обучение пройденным, а тропа при возврате вызывает этот сценарий.
final class ClaimStartingSet {
  /// Создаёт сценарий.
  ClaimStartingSet(this._campaign, this._repository, this._settings, this._record);

  final LoadCampaign _campaign;
  final CampaignRepository _repository;
  final SettingsRepository _settings;
  final RecordCampaignResult _record;

  /// Выдаёт набор, если «Первая партия» пройдена, а узел 0 нет. Возвращает победу для экрана награды или `null`,
  /// когда выдавать нечего (набор уже выдан, обучение не пройдено или каталога нет).
  ///
  /// Вызовы идут по очереди: проверка «узел 0 не пройден» и запись не должны пересекаться у двух вызовов.
  Future<CampaignWon?> call() {
    final result = _queue.then((_) => _claim());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _queue = Future.value();

  Future<CampaignWon?> _claim() async {
    final data = await _campaign();
    if (data == null) return null;
    final first = data.catalog.firstNode;
    if ((await _repository.load()).containsKey(first.id)) return null;
    if (!(await _settings.watch().first).firstMatchPassed) return null;
    return switch (await _record(first.id, const CampaignMatchFacts.withoutMatch())) {
      // Узел 0 уже записал другой вызов, пока шла проверка: показывать нечего.
      final CampaignWon won when won.firstWin => won,
      _ => null,
    };
  }
}
