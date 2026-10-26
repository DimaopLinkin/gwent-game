import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_topic.dart';

/// Тексты темы справочника: всё берётся из строк интерфейса, страница только раскладывает их.
final class HowToTexts {
  /// Тексты темы [topic].
  const HowToTexts(this.topic, this.l10n);

  /// Тема.
  final HowToTopic topic;

  /// Строки интерфейса.
  final AppLocalizations l10n;

  /// Название темы.
  String get title => switch (topic) {
    HowToTopic.goal => l10n.howToGoalTitle,
    HowToTopic.handAndDeck => l10n.howToHandAndDeckTitle,
    HowToTopic.turnAndPass => l10n.howToTurnAndPassTitle,
    HowToTopic.rowsAndPower => l10n.howToRowsAndPowerTitle,
    HowToTopic.weather => l10n.howToWeatherTitle,
    HowToTopic.abilities => l10n.howToAbilitiesTitle,
    HowToTopic.specials => l10n.howToSpecialsTitle,
    HowToTopic.leadersAndFactions => l10n.howToLeadersTitle,
  };

  /// Подпись темы в списке.
  String get summary => switch (topic) {
    HowToTopic.goal => l10n.howToGoalSummary,
    HowToTopic.handAndDeck => l10n.howToHandAndDeckSummary,
    HowToTopic.turnAndPass => l10n.howToTurnAndPassSummary,
    HowToTopic.rowsAndPower => l10n.howToRowsAndPowerSummary,
    HowToTopic.weather => l10n.howToWeatherSummary,
    HowToTopic.abilities => l10n.howToAbilitiesSummary,
    HowToTopic.specials => l10n.howToSpecialsSummary,
    HowToTopic.leadersAndFactions => l10n.howToLeadersSummary,
  };

  /// Абзацы страницы по порядку.
  List<String> get paragraphs => switch (topic) {
    HowToTopic.goal => [l10n.howToGoalText1, l10n.howToGoalText2, l10n.howToGoalText3],
    HowToTopic.handAndDeck => [l10n.howToHandAndDeckText1, l10n.howToHandAndDeckText2, l10n.howToHandAndDeckText3],
    HowToTopic.turnAndPass => [l10n.howToTurnAndPassText1, l10n.howToTurnAndPassText2, l10n.howToTurnAndPassText3],
    HowToTopic.rowsAndPower => [
      l10n.howToRowsAndPowerText1,
      l10n.howToRowsAndPowerText2,
      l10n.howToRowsAndPowerText3,
    ],
    HowToTopic.weather => [l10n.howToWeatherText1, l10n.howToWeatherText2, l10n.howToWeatherText3],
    HowToTopic.abilities => [l10n.howToAbilitiesText1],
    HowToTopic.specials => [l10n.howToSpecialsText1],
    HowToTopic.leadersAndFactions => [l10n.howToLeadersText1, l10n.howToLeadersText2],
  };

  /// Главная мысль темы для блока «Запомните».
  String get remember => switch (topic) {
    HowToTopic.goal => l10n.howToGoalRemember,
    HowToTopic.handAndDeck => l10n.howToHandAndDeckRemember,
    HowToTopic.turnAndPass => l10n.howToTurnAndPassRemember,
    HowToTopic.rowsAndPower => l10n.howToRowsAndPowerRemember,
    HowToTopic.weather => l10n.howToWeatherRemember,
    HowToTopic.abilities => l10n.howToAbilitiesRemember,
    HowToTopic.specials => l10n.howToSpecialsRemember,
    HowToTopic.leadersAndFactions => l10n.howToLeadersRemember,
  };

  /// Иконка темы в списке.
  GwentIcon get icon => switch (topic) {
    HowToTopic.goal => GwentIcon.iconLifeGem,
    HowToTopic.handAndDeck => GwentIcon.iconHand,
    HowToTopic.turnAndPass => GwentIcon.iconPause,
    HowToTopic.rowsAndPower => GwentIcon.rowMelee,
    HowToTopic.weather => GwentIcon.weatherFrost,
    HowToTopic.abilities => GwentIcon.abilitySpy,
    HowToTopic.specials => GwentIcon.specialDecoy,
    HowToTopic.leadersAndFactions => GwentIcon.iconLeader,
  };
}
