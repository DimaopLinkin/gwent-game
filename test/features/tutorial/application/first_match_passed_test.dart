import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/tutorial/application/mark_first_match_passed.dart';
import 'package:gwent/src/features/tutorial/application/start_first_match.dart';
import 'package:gwent/src/features/tutorial/application/watch_first_match_passed.dart';

import 'package:gwent_content/gwent_content.dart' show InMemoryContentSource;

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('прохождение записывается один раз и не трогает остальные настройки', () async {
    final settings = InMemorySettingsRepository()..saved = const AppSettings(playerName: 'Цири', confirmPass: true);
    final mark = MarkFirstMatchPassed(settings);

    await mark();
    expect(settings.saved.firstMatchPassed, isTrue);
    expect(settings.saved.confirmPass, isTrue);
    expect(settings.saved.playerName, 'Цири');

    final saved = settings.saved;
    await mark();
    expect(settings.saved, saved, reason: 'повторный вызов ничего не меняет');
  });

  test('слежение выдаёт значение сразу и только когда оно изменилось', () async {
    final settings = InMemorySettingsRepository();
    final values = <bool>[];
    final subscription = WatchFirstMatchPassed(settings)().listen(values.add);
    await pumpEventQueue();
    expect(values, [false]);

    await settings.save(settings.saved.copyWith(confirmPass: true));
    await pumpEventQueue();
    expect(values, [false], reason: 'другая настройка не повод для нового значения');

    await settings.save(settings.saved.copyWith(firstMatchPassed: true));
    await pumpEventQueue();
    expect(values, [false, true]);
    await subscription.cancel();
  });

  test('набор карт не загрузился: партия не начинается, причина называется', () async {
    final result = await StartFirstMatch(LoadGameContent(InMemoryContentSource(const {})))();
    expect(result, isA<FirstMatchUnavailable>().having((unavailable) => unavailable.issues, 'issues', isNotEmpty));
  });

  test('настоящий набор: партия начинается, колоды и сценарий на месте', () async {
    final result = await StartFirstMatch(
      LoadGameContent(AssetContentSource.basePack(rootBundle)),
      botThinkTime: Duration.zero,
    )();
    expect(result, isA<FirstMatchStarted>());
    final started = result as FirstMatchStarted;
    expect(started.session.recordsHistory, isFalse);
    expect(started.director.current, isNotNull);
    await started.session.table.close();
  });
}
