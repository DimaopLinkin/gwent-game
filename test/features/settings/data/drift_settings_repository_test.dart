import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/settings/data/drift_settings_repository.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = DriftSettingsRepository(db);
  });

  tearDown(() => db.close());

  test('без сохранённых значений действуют значения по умолчанию', () async {
    expect(await repository.watch().first, const AppSettings());
  });

  test('сохранённые настройки читаются, а null возвращает значение по умолчанию', () async {
    await repository.save(const AppSettings(playerName: 'Геральт'));
    expect(await repository.watch().first, const AppSettings(playerName: 'Геральт'));

    await repository.save(const AppSettings());
    expect(await repository.watch().first, const AppSettings());
    expect(await db.select(db.settings).get(), isEmpty);
  });

  test('все настройки возвращаются такими, какими сохранены', () async {
    final settings = AppSettings(
      playerName: 'Цири',
      confirmPass: false,
      animationSpeed: AnimationSpeed.fast,
      hints: false,
      haptics: false,
      musicVolume: 0,
      effectsVolume: 100,
      contentCheckedAt: DateTime.utc(2026, 10, 18, 9, 30),
      botDifficulty: BotDifficulty.deathMatch,
      localNetworkExplained: true,
    );

    await repository.save(settings);

    expect(await repository.watch().first, settings);
  });

  test('значения по умолчанию в базе не хранятся', () async {
    await repository.save(const AppSettings(confirmPass: false));

    final keys = {for (final row in await db.select(db.settings).get()) row.key};
    expect(keys, {'confirm_pass'});
  });

  test('нечитаемые значения читаются как значения по умолчанию, громкость зажимается в границы', () async {
    Future<void> put(String key, String value) =>
        db.into(db.settings).insertOnConflictUpdate(SettingsCompanion(key: Value(key), value: Value(value)));
    await put('confirm_pass', 'может быть');
    await put('animation_speed', 'мгновенная');
    await put('hints', '1');
    await put('music_volume', 'громко');
    await put('effects_volume', '250');
    await put('content_checked_at', 'вчера');
    await put('bot_difficulty', 'невозможный');

    final settings = await repository.watch().first;

    expect(settings.confirmPass, isTrue);
    expect(settings.animationSpeed, AnimationSpeed.normal);
    expect(settings.hints, isTrue);
    expect(settings.musicVolume, 70);
    expect(settings.effectsVolume, 100);
    expect(settings.contentCheckedAt, isNull);
    expect(settings.botDifficulty, BotDifficulty.normal);
  });
}
