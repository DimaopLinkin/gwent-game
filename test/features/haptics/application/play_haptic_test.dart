import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/haptics/application/play_haptic.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemorySettingsRepository settings;
  late RecordingHapticOutput output;
  late PlayHaptic haptic;

  setUp(() {
    settings = InMemorySettingsRepository();
    output = RecordingHapticOutput();
    haptic = PlayHaptic(output, WatchSettings(settings));
    addTearDown(haptic.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('по умолчанию вибрация включена, даже пока настройки не прочитаны', () {
    haptic(HapticPattern.medium);
    expect(output.played, [HapticPattern.medium]);
  });

  test('выключатель в настройках глушит вибрацию и включает обратно', () async {
    await settings.save(const AppSettings(haptics: false));
    await settle();
    haptic(HapticPattern.heavy);
    expect(output.played, isEmpty);

    await settings.save(const AppSettings());
    await settle();
    haptic(HapticPattern.heavy);
    expect(output.played, [HapticPattern.heavy]);
  });

  test('образец играет и при выключенной вибрации', () async {
    await settings.save(const AppSettings(haptics: false));
    await settle();
    haptic(HapticPattern.medium, force: true);
    expect(output.played, [HapticPattern.medium]);
  });
}
