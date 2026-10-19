import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/fakes.dart';
import '../../../../support/match_fixtures.dart';
import 'field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;
  late RecordingSoundOutput output;
  late FieldCubit cubit;

  setUpAll(() async => content = await loadBaseContent());
  setUp(() {
    cards = TestCards(content);
    output = RecordingSoundOutput();
    final sound = PlaySound(output, WatchSettings(InMemorySettingsRepository()));
    addTearDown(sound.dispose);
    cubit = FieldCubit(sound: sound);
    addTearDown(cubit.close);
  });

  MatchInProgress progress(PlayerView view, {List<GameEvent> events = const []}) =>
      MatchInProgress(view: view, content: content, roster: rosterOf(cards), events: events);

  test('знакомство перед партией звучит один раз', () {
    cubit.onMatchState(MatchIntro(rosterOf(cards)));
    expect(output.effects, [SoundEffect.matchOpening]);
  });

  test('раздача звучит один раз за партию, а новая партия снова', () {
    final redraw = viewOf(cards, phase: MatchPhase.redraw);
    cubit
      ..onMatchState(progress(redraw))
      ..onMatchState(progress(redraw));
    expect(output.effects, [SoundEffect.matchStart]);

    cubit
      ..onMatchState(MatchIntro(rosterOf(cards)))
      ..onMatchState(progress(redraw));
    expect(output.effects, [SoundEffect.matchStart, SoundEffect.matchOpening, SoundEffect.matchStart]);
  });

  test('пересдача звучит, когда карту меняю я, и молчит, когда меняет соперник', () {
    final redraw = viewOf(cards, phase: MatchPhase.redraw);
    final returned = cards.unit(Row.melee);
    final drawn = cards.unit(Row.ranged);
    cubit.onMatchState(progress(redraw));
    output.played.clear();
    cubit.onMatchState(
      progress(
        redraw,
        events: [CardRedrawn(Seat.two, returned: returned, drawn: drawn)],
      ),
    );
    expect(output.played, isEmpty);
    cubit.onMatchState(
      progress(
        redraw,
        events: [CardRedrawn(Seat.one, returned: returned, drawn: drawn)],
      ),
    );
    expect(output.effects, [SoundEffect.redraw]);
  });

  test('первый раунд звучит, остальные нет; ход звучит по тому, чей он', () {
    cubit.onMatchState(
      progress(viewOf(cards), events: const [RoundStarted(1, Seat.one), TurnStarted(Seat.one)]),
    );
    expect(output.effects, [SoundEffect.firstRoundStart]);

    cubit
      ..dismissBanner()
      ..dismissBanner();
    expect(output.effects, [SoundEffect.firstRoundStart, SoundEffect.turnMine]);
  });

  test('ход соперника, пас и баннер второго раунда', () {
    cubit.onMatchState(progress(viewOf(cards), events: const [Passed(Seat.one, auto: false)]));
    expect(output.effects, [SoundEffect.pass]);
    cubit.dismissBanner();
    cubit.onMatchState(progress(viewOf(cards), events: const [RoundStarted(2, Seat.two), TurnStarted(Seat.two)]));
    // Баннер второго раунда без звука, поэтому звучит только ход соперника, когда до него дойдёт очередь.
    expect(output.effects, [SoundEffect.pass]);
    cubit.dismissBanner();
    expect(output.effects, [SoundEffect.pass, SoundEffect.turnOpponent]);
  });

  test('выбор карты звучит, повторный выбор той же карты нет', () {
    final card = cards.unit(Row.melee);
    cubit
      ..toggleSelected(card.id)
      ..toggleSelected(card.id)
      ..select(card.id);
    expect(output.effects, [SoundEffect.select, SoundEffect.select]);
  });

  test('листы сброса и лидера звучат при открытии', () {
    cubit
      ..openDiscard(mine: true)
      ..closeOverlay()
      ..openLeader(mine: false);
    expect(output.effects, [SoundEffect.sheetOpen, SoundEffect.sheetOpen]);
  });

  test('тост-отказ звучит предупреждением, каждый новый раз', () {
    cubit
      ..say(FieldMessage.opponentTurn)
      ..say(FieldMessage.opponentTurn);
    expect(output.effects, [SoundEffect.warning, SoundEffect.warning]);
  });

  test('без звукового сценария держатель молчит и не падает', () {
    final silent = FieldCubit();
    addTearDown(silent.close);
    silent
      ..say(FieldMessage.refused)
      ..openDiscard(mine: true)
      ..playSound(SoundEffect.pass);
    expect(output.played, isEmpty);
  });
}
