import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

/// Какой вибрацией сопровождается звук события (ADR 0031): вибрация идёт в тех же местах и в те же моменты, что и
/// звук. `null` — событие без вибрации.
extension SoundHaptics on SoundEffect {
  /// Паттерн вибрации этого события.
  HapticPattern? get haptic => switch (this) {
    SoundEffect.unitMelee || SoundEffect.unitRanged || SoundEffect.unitSiege => HapticPattern.medium,
    SoundEffect.hero => HapticPattern.heavy,
    SoundEffect.spy => HapticPattern.double,
    SoundEffect.medic || SoundEffect.morale => HapticPattern.soft,
    SoundEffect.muster => HapticPattern.triple,
    SoundEffect.bond ||
    SoundEffect.draw ||
    SoundEffect.select ||
    SoundEffect.redraw ||
    SoundEffect.deckAdd => HapticPattern.tick,
    SoundEffect.horn || SoundEffect.mardroeme || SoundEffect.decoy => HapticPattern.knock,
    SoundEffect.scorch => HapticPattern.rumble,
    SoundEffect.frost || SoundEffect.fog || SoundEffect.rain => HapticPattern.ripple,
    SoundEffect.clearWeather || SoundEffect.firstRoundStart => HapticPattern.soft,
    SoundEffect.turnMine => HapticPattern.double,
    SoundEffect.pass || SoundEffect.matchStart => HapticPattern.medium,
    SoundEffect.roundWon => HapticPattern.rise,
    SoundEffect.roundLost || SoundEffect.matchLost => HapticPattern.fall,
    SoundEffect.matchWon => HapticPattern.triumph,
    SoundEffect.warning => HapticPattern.warn,
    SoundEffect.matchOpening ||
    SoundEffect.turnOpponent ||
    SoundEffect.sheetOpen ||
    SoundEffect.deckRemove ||
    SoundEffect.menuOpen => null,
  };
}
