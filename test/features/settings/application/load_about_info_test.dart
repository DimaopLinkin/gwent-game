import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/domain/app_info.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/settings/application/load_about_info.dart';
import 'package:gwent_content/gwent_content.dart' show InMemoryContentSource;
import 'package:gwent_net/gwent_net.dart' show protocolVersion;

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LoadGameContent content() => LoadGameContent(AssetContentSource.basePack(rootBundle));

  test('версии приложения, сборки, набора карт и протокола', () async {
    final info = await LoadAboutInfo(const FakeAppInfo('1.2.3', '45'), content())();

    expect(info.appVersion, '1.2.3');
    expect(info.buildNumber, '45');
    expect(info.protocolVersion, protocolVersion);
    expect(info.packVersion, isNotNull);
  });

  test('версия приложения не прочиталась: остаётся пустой, остальное есть', () async {
    final info = await LoadAboutInfo(_BrokenAppInfo(), content())();

    expect(info.appVersion, isNull);
    expect(info.buildNumber, isNull);
    expect(info.packVersion, isNotNull);
  });

  test('набор карт не прошёл проверку: версии набора нет', () async {
    final info = await LoadAboutInfo(const FakeAppInfo(), LoadGameContent(InMemoryContentSource(const {})))();

    expect(info.packVersion, isNull);
    expect(info.appVersion, '1.0.0');
  });
}

final class _BrokenAppInfo implements AppInfo {
  @override
  Future<String> version() => Future.error(StateError('нет платформы'));

  @override
  Future<String> buildNumber() => Future.error(StateError('нет платформы'));
}
