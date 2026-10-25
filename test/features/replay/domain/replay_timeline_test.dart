import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/replay/domain/replay_timeline.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/match_fixtures.dart';
import '../../match/presentation/field/field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('конец раунда в кадре, который не показывается, закрывает ближайший показанный шаг', () async {
    final cards = TestCards(await loadBaseContent());
    final before = viewOf(cards);
    final hidden = viewOf(cards, phase: MatchPhase.redraw);
    final after = viewOf(cards, round: 2);
    const result = RoundResult(round: 1, scores: {Seat.one: 3, Seat.two: 1}, winner: Seat.one);

    ReplayFrame frame(PlayerView view, [List<GameEvent> events = const []]) => ReplayFrame(
      views: {Seat.one: view},
      events: {Seat.one: events},
    );
    final timeline = ReplayTimeline(
      frames: [
        frame(before),
        frame(hidden, const [RoundEnded(result)]),
        frame(after, const [RoundStarted(2, Seat.one)]),
      ],
      seats: const {Seat.one},
      perspective: Seat.one,
    );

    final steps = timeline.stepsFor(Seat.one);
    expect(steps.map((step) => step.frame), [0, 2]);
    expect(steps.first.closing, isNull);
    expect(steps.last.closing, before, reason: 'поле перед кадром с концом раунда');
    expect(steps.last.events, const [RoundEnded(result), RoundStarted(2, Seat.one)]);
  });
}
