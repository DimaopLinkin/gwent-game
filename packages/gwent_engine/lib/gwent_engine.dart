/// Движок правил Гвинта из «Ведьмака 3».
///
/// Чистый Dart: без Flutter, `dart:io`, `DateTime.now()` и случайности без сида.
/// Матч описывается детерминированной функцией над намерениями игроков: `MatchEngine.apply` и `MatchEngine.project`.
library;

export 'src/cards/card_catalog.dart';
export 'src/cards/card_definition.dart';
export 'src/cards/deck.dart';
export 'src/cards/faction.dart';
export 'src/cards/ids.dart';
export 'src/cards/leader_ability.dart';
export 'src/cards/row.dart';
export 'src/cards/special_ability.dart';
export 'src/cards/unit_ability.dart';
export 'src/engine/engine_result.dart';
export 'src/engine/gwent_engine.dart';
export 'src/engine/match_engine.dart';
export 'src/engine/match_setup.dart';
export 'src/engine/reject.dart';
export 'src/engine_info.dart';
export 'src/event/game_event.dart';
export 'src/intent/intent.dart';
export 'src/random/rng.dart';
export 'src/rules/deck_validator.dart';
export 'src/rules/deck_violation.dart';
export 'src/rules/game_rules.dart';
export 'src/state/card_instance.dart';
export 'src/state/choice.dart';
export 'src/state/entry_source.dart';
export 'src/state/field_card.dart';
export 'src/state/match_outcome.dart';
export 'src/state/match_phase.dart';
export 'src/state/match_state.dart';
export 'src/state/player_state.dart';
export 'src/state/round_result.dart';
export 'src/state/row_slot.dart';
export 'src/state/row_state.dart';
export 'src/state/seat.dart';
export 'src/state/weather_card.dart';
export 'src/view/player_view.dart';
