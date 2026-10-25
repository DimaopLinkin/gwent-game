import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent/src/features/match_history/domain/replay_recorder.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' show InMemoryMatchJournal, MatchRecord, Ruleset;

import '../../../support/match_fixtures.dart';
import '../../match/presentation/field/field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ruleset = Ruleset(id: 'pack', hash: 'h', engineVersion: 1);
  late TestCards cards;

  setUpAll(() async => cards = TestCards(await loadBaseContent()));

  test('гость: записи нет, пока партия не кончилась; снимок без событий после переподключения кадром не считается', () {
    final recorder = NetworkReplayRecorder(perspective: Seat.two, ruleset: ruleset);
    final playing = viewOf(cards);
    final finished = viewOf(
      cards,
      phase: MatchPhase.finished,
      outcome: const MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation),
    );

    recorder.add(playing, const [RoundStarted(1, Seat.one)]);
    recorder.add(playing, const []);
    expect(recorder.log, isNull);
    recorder.add(finished, const [MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation))]);

    final log = recorder.log! as FramesReplayLog;
    expect(log.frames.map((frame) => frame.view.phase), [MatchPhase.playing, MatchPhase.finished]);
    expect(log.perspective, Seat.two);

    recorder.add(playing, const []);
    expect((recorder.log! as FramesReplayLog).frames, hasLength(2), reason: 'после конца запись не меняется');
  });

  test('хост: в конце партии снимается журнал, кадры не копятся', () {
    final journal = InMemoryMatchJournal()
      ..begin(const MatchRecord(matchId: 'm', ruleset: ruleset, seed: 1, one: _deck, two: _deck));
    final recorder = NetworkReplayRecorder(perspective: Seat.one, ruleset: ruleset, journal: journal);

    recorder.add(viewOf(cards), const []);
    expect(recorder.log, isNull);
    recorder.add(viewOf(cards, phase: MatchPhase.finished), const []);

    expect(recorder.log, JournalReplayLog(journal.record!, perspective: Seat.one));
  });
}

const _deck = Deck(leader: LeaderId('l'), cards: [CardId('c')]);
