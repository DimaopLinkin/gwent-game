import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';
import 'package:gwent/src/features/haptics/domain/sound_haptics.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

void main() {
  test('таблица «событие → паттерн» из ADR 0031', () {
    expect(SoundEffect.unitMelee.haptic, HapticPattern.medium);
    expect(SoundEffect.hero.haptic, HapticPattern.heavy);
    expect(SoundEffect.spy.haptic, HapticPattern.double);
    expect(SoundEffect.muster.haptic, HapticPattern.triple);
    expect(SoundEffect.horn.haptic, HapticPattern.knock);
    expect(SoundEffect.scorch.haptic, HapticPattern.rumble);
    expect(SoundEffect.frost.haptic, HapticPattern.ripple);
    expect(SoundEffect.roundWon.haptic, HapticPattern.rise);
    expect(SoundEffect.matchWon.haptic, HapticPattern.triumph);
    expect(SoundEffect.roundLost.haptic, HapticPattern.fall);
    expect(SoundEffect.warning.haptic, HapticPattern.warn);
  });

  test('ход соперника, меню, листы и знакомство не вибрируют', () {
    for (final effect in [
      SoundEffect.turnOpponent,
      SoundEffect.menuOpen,
      SoundEffect.sheetOpen,
      SoundEffect.matchOpening,
      SoundEffect.deckRemove,
    ]) {
      expect(effect.haptic, isNull, reason: '$effect');
    }
  });

  test('у каждого паттерна есть касания, первое без паузы, паузы от 60 до 110 мс', () {
    for (final pattern in HapticPattern.values) {
      expect(pattern.steps, isNotEmpty, reason: '$pattern');
      expect(pattern.steps.first.after, Duration.zero, reason: '$pattern');
      for (final step in pattern.steps.skip(1)) {
        expect(step.after.inMilliseconds, inInclusiveRange(60, 110), reason: '$pattern');
      }
    }
  });
}
