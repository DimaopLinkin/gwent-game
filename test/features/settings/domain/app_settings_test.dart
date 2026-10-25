import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;

void main() {
  test('значения по умолчанию', () {
    const settings = AppSettings();

    expect(settings.playerName, isNull);
    expect(settings.confirmPass, isFalse);
    expect(settings.animationSpeed, AnimationSpeed.normal);
    expect(settings.hints, isTrue);
    expect(settings.haptics, isTrue);
    expect(settings.musicVolume, 70);
    expect(settings.effectsVolume, 85);
    expect(settings.contentCheckedAt, isNull);
    expect(settings.botDifficulty, BotDifficulty.normal);
    expect(settings.localNetworkExplained, isFalse);
  });

  test('copyWith меняет названные поля и оставляет имя игрока', () {
    final checked = DateTime.utc(2026, 10, 18);
    final settings = const AppSettings(
      playerName: 'Геральт',
    ).copyWith(confirmPass: true, animationSpeed: AnimationSpeed.fast, musicVolume: 10, contentCheckedAt: checked);

    expect(settings.playerName, 'Геральт');
    expect(settings.confirmPass, isTrue);
    expect(settings.animationSpeed, AnimationSpeed.fast);
    expect(settings.hints, isTrue);
    expect(settings.musicVolume, 10);
    expect(settings.effectsVolume, 85);
    expect(settings.contentCheckedAt, checked);
  });

  test('withPlayerName меняет только имя, null стирает его', () {
    final settings = const AppSettings(hints: false, effectsVolume: 5).withPlayerName('Йеннифэр');
    expect(settings.playerName, 'Йеннифэр');
    expect(settings.hints, isFalse);
    expect(settings.effectsVolume, 5);

    expect(settings.withPlayerName(null).playerName, isNull);
    expect(const AppSettings(localNetworkExplained: true).withPlayerName('Ласка').localNetworkExplained, isTrue);
  });

  test('равенство учитывает все поля', () {
    const base = AppSettings(playerName: 'А');

    expect(base, const AppSettings(playerName: 'А'));
    expect(base.hashCode, const AppSettings(playerName: 'А').hashCode);
    expect(base, isNot(base.copyWith(confirmPass: true)));
    expect(base, isNot(base.copyWith(animationSpeed: AnimationSpeed.fast)));
    expect(base, isNot(base.copyWith(hints: false)));
    expect(base, isNot(base.copyWith(haptics: false)));
    expect(base, isNot(base.copyWith(localNetworkExplained: true)));
    expect(base, isNot(base.copyWith(musicVolume: 0)));
    expect(base, isNot(base.copyWith(botDifficulty: BotDifficulty.hard)));
    expect(base, isNot(base.copyWith(effectsVolume: 0)));
    expect(base, isNot(base.copyWith(contentCheckedAt: DateTime.utc(2026))));
    expect(base, isNot(base.withPlayerName('Б')));
  });
}
