import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/haptics/application/play_haptic.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';
import 'package:gwent/src/features/settings/application/check_content_update.dart';
import 'package:gwent/src/features/settings/application/load_about_info.dart';
import 'package:gwent/src/features/settings/application/save_settings.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';
import 'package:gwent/src/features/settings/presentation/settings_cubit.dart';
import 'package:gwent/src/features/settings/presentation/settings_state.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent_content/gwent_content.dart' show ContentSource, InMemoryContentSource;

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 18, 10);
  late InMemorySettingsRepository repository;

  setUp(() => repository = InMemorySettingsRepository());

  SettingsCubit newCubit({
    SettingsRepository? storage,
    ContentSource? source,
    Duration minCheck = Duration.zero,
    PlaySound? sound,
    PlayHaptic? haptic,
  }) {
    final content = LoadGameContent(source ?? AssetContentSource.basePack(rootBundle));
    final repo = storage ?? repository;
    final cubit = SettingsCubit(
      watchSettings: WatchSettings(repo),
      saveSettings: SaveSettings(repo),
      loadAboutInfo: LoadAboutInfo(const FakeAppInfo('1.2.3', '7'), content),
      checkContentUpdate: CheckContentUpdate(content, FakeClock(now)),
      minCheckDuration: minCheck,
      sound: sound,
      haptic: haptic,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<SettingsLoaded> loaded(SettingsCubit cubit) async {
    if (cubit.state is SettingsLoaded) return cubit.state as SettingsLoaded;
    return await cubit.stream.firstWhere((state) => state is SettingsLoaded) as SettingsLoaded;
  }

  test('сначала загрузка, потом сохранённые настройки и версии', () async {
    repository.saved = const AppSettings(playerName: 'Геральт', hints: false);
    final cubit = newCubit();
    expect(cubit.state, isA<SettingsLoading>());

    final state = await loaded(cubit);

    expect(state.settings, const AppSettings(playerName: 'Геральт', hints: false));
    expect(state.about.appVersion, '1.2.3');
    expect(state.about.buildNumber, '7');
    expect(state.about.packVersion, isNotNull);
    expect(state.update, ContentUpdateStatus.idle);
  });

  test('хранилище не читается: состояние ошибки', () async {
    final cubit = newCubit(storage: _BrokenRepository());

    expect(await cubit.stream.firstWhere((state) => state is! SettingsLoading), isA<SettingsFailed>());
  });

  test('каждое изменение попадает в состояние и в хранилище', () async {
    final cubit = newCubit();
    await loaded(cubit);

    cubit
      ..setPlayerName(' Йеннифэр ')
      ..setConfirmPass(value: false)
      ..setAnimationSpeed(AnimationSpeed.fast)
      ..setHints(value: false);

    final settings = (cubit.state as SettingsLoaded).settings;
    expect(settings.confirmPass, isFalse);
    expect(settings.animationSpeed, AnimationSpeed.fast);
    expect(settings.hints, isFalse);
    expect(repository.saved.playerName, 'Йеннифэр', reason: 'имя сохраняется без пробелов по краям');
    expect(repository.saved.confirmPass, isFalse);
    expect(repository.saved.animationSpeed, AnimationSpeed.fast);
    expect(repository.saved.hints, isFalse);
  });

  test('вибрация: выключатель сохраняется, при включении звучит образец', () async {
    final output = RecordingHapticOutput();
    final haptic = PlayHaptic(output, WatchSettings(repository));
    addTearDown(haptic.dispose);
    final cubit = newCubit(haptic: haptic);
    await loaded(cubit);

    cubit.setHaptics(value: false);
    expect((cubit.state as SettingsLoaded).settings.haptics, isFalse);
    expect(repository.saved.haptics, isFalse);
    expect(output.played, isEmpty, reason: 'при выключении образца нет');

    cubit.setHaptics(value: true);
    expect(repository.saved.haptics, isTrue);
    expect(output.played, [HapticPattern.medium], reason: 'образец играет, ещё не дождавшись записи');
  });

  test('громкость меняется в состоянии сразу, а в хранилище попадает после отпускания ползунка', () async {
    final cubit = newCubit();
    await loaded(cubit);

    cubit
      ..changeMusicVolume(30)
      ..changeMusicVolume(20)
      ..changeEffectsVolume(5);

    expect((cubit.state as SettingsLoaded).settings.musicVolume, 20);
    expect((cubit.state as SettingsLoaded).settings.effectsVolume, 5);
    expect(repository.saved, const AppSettings(), reason: 'пока ползунок под пальцем, запись не идёт');

    cubit.saveVolumes();

    expect(repository.saved.musicVolume, 20);
    expect(repository.saved.effectsVolume, 5);
  });

  group('образец громкости эффектов', () {
    late RecordingSoundOutput output;
    late PlaySound sound;

    setUp(() {
      output = RecordingSoundOutput();
      sound = PlaySound(output, WatchSettings(repository));
      addTearDown(sound.dispose);
    });

    test('игрок отпустил ползунок эффектов: звучит образец с выбранной громкостью, ещё не сохранённой', () async {
      final cubit = newCubit(sound: sound);
      await loaded(cubit);

      cubit
        ..changeEffectsVolume(30)
        ..saveVolumes();

      expect(output.played.single.effect, SoundEffect.turnMine);
      expect(output.played.single.volume, 0.3);
    });

    test('ползунок музыки образца не даёт, и повторное отпускание без перемены тоже', () async {
      final cubit = newCubit(sound: sound);
      await loaded(cubit);

      cubit
        ..changeMusicVolume(10)
        ..saveVolumes();
      expect(output.played, isEmpty);

      cubit
        ..changeEffectsVolume(60)
        ..saveVolumes()
        ..saveVolumes();
      expect(output.played, hasLength(1));
    });
  });

  test('сбой записи не роняет экран: настройка остаётся в состоянии', () async {
    final cubit = newCubit(storage: _FailingSaveRepository());
    await loaded(cubit);

    cubit.setHints(value: false);
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as SettingsLoaded).settings.hints, isFalse);
  });

  test('проверка обновления: проверка, затем актуален, дата сохранена', () async {
    final cubit = newCubit();
    await loaded(cubit);
    final states = <ContentUpdateStatus>[];
    final subscription = cubit.stream.listen((state) => states.add((state as SettingsLoaded).update));
    addTearDown(subscription.cancel);

    await cubit.checkContentUpdate();
    await Future<void>.delayed(Duration.zero);

    expect(states, [ContentUpdateStatus.checking, ContentUpdateStatus.upToDate]);
    expect((cubit.state as SettingsLoaded).settings.contentCheckedAt, now);
    expect(repository.saved.contentCheckedAt, now);
  });

  test('проверка держит состояние «Проверка…» не короче заданного времени', () async {
    final cubit = newCubit(minCheck: const Duration(milliseconds: 300));
    await loaded(cubit);

    final started = Stopwatch()..start();
    await cubit.checkContentUpdate();

    expect(started.elapsedMilliseconds, greaterThanOrEqualTo(280));
  });

  test('повторное нажатие во время проверки ничего не запускает', () async {
    final cubit = newCubit(minCheck: const Duration(milliseconds: 100));
    await loaded(cubit);
    final states = <ContentUpdateStatus>[];
    final subscription = cubit.stream.listen((state) => states.add((state as SettingsLoaded).update));
    addTearDown(subscription.cancel);

    final first = cubit.checkContentUpdate();
    await cubit.checkContentUpdate();
    await first;
    await Future<void>.delayed(Duration.zero);

    expect(states, [ContentUpdateStatus.checking, ContentUpdateStatus.upToDate]);
  });

  test('набор не прошёл проверку: проверить не удалось, дата не записывается', () async {
    final cubit = newCubit(source: InMemoryContentSource(const {}));
    await loaded(cubit);

    await cubit.checkContentUpdate();

    final state = cubit.state as SettingsLoaded;
    expect(state.update, ContentUpdateStatus.failed);
    expect(state.settings.contentCheckedAt, isNull);
    expect(state.about.packVersion, isNull);
    expect(repository.saved.contentCheckedAt, isNull);
  });
}

final class _BrokenRepository implements SettingsRepository {
  @override
  Stream<AppSettings> watch() => Stream.error(StateError('база недоступна'));

  @override
  Future<void> save(AppSettings settings) async {}
}

final class _FailingSaveRepository implements SettingsRepository {
  @override
  Stream<AppSettings> watch() => Stream.value(const AppSettings());

  @override
  Future<void> save(AppSettings settings) => Future.error(StateError('диск полон'));
}
