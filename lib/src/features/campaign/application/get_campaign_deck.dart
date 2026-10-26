import 'package:gwent/src/features/campaign/application/list_campaign_decks.dart';
import 'package:gwent/src/features/campaign/domain/campaign_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: колода, с которой игрок идёт в партию кампании (ADR 0033).
final class GetCampaignDeck {
  /// Создаёт сценарий.
  const GetCampaignDeck(this._list, this._settings);

  final ListCampaignDecks _list;
  final SettingsRepository _settings;

  /// Выбранная колода, если она ещё годится для кампании; иначе самая недавно изменённая годная колода.
  /// `null`, если годных колод нет: игроку предлагают собрать её в конструкторе кампании.
  ///
  /// Колоды кампании не создаются сами, как стартовые колоды свободной игры, и выбор при чтении не перезаписывается.
  Future<Deck?> call() async {
    final chosenId = (await _settings.watch().first).campaignDeckId;
    final ready = [
      for (final CampaignDeck entry in await _list())
        if (entry.isReady) entry.deck,
    ];
    return ready.where((deck) => deck.id == chosenId).firstOrNull ?? ready.firstOrNull;
  }
}
