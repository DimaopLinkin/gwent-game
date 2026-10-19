import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/application/network_readiness.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';

import '../../../support/fakes.dart';
import '../support/lobby_fakes.dart';

void main() {
  late FakeNetworkAccess access;
  late InMemorySettingsRepository settings;
  late NetworkReadiness readiness;

  setUp(() {
    access = FakeNetworkAccess();
    settings = InMemorySettingsRepository();
    readiness = NetworkReadiness(access, settings);
  });

  group('check', () {
    test('Wi-Fi включён, платформа не спрашивает доступ: мешать нечему', () async {
      expect(await readiness.check(), isNull);
    });

    test('Wi-Fi выключен: сначала об этом, даже если на iOS ещё нужно пояснение', () async {
      access
        ..wifiOn = false
        ..asksLocalNetworkPermission = true;

      expect(await readiness.check(), NetworkProblem.wifiOff);
    });

    test(
      'Wi-Fi выключен, но есть мобильная сеть: до попытки не мешаем (Wi-Fi без интернета ОС так и показывает)',
      () async {
        access
          ..wifiOn = false
          ..mobileOn = true;

        expect(await readiness.check(), isNull);
        expect(await readiness.diagnose(), NetworkProblem.wifiOff);
      },
    );

    test('iOS: пояснение перед системным запросом показывается, пока игрок его не прочитал', () async {
      access.asksLocalNetworkPermission = true;
      expect(await readiness.check(), NetworkProblem.localNetworkExplainer);

      await readiness.markExplained();

      expect(await readiness.check(), isNull);
      expect(settings.saved.localNetworkExplained, isTrue);
    });

    test('пояснение запоминается, не стирая остальные настройки', () async {
      await settings.save(const AppSettings(playerName: 'Цири', hints: false));

      await readiness.markExplained();

      expect(settings.saved, const AppSettings(playerName: 'Цири', hints: false, localNetworkExplained: true));
    });
  });

  group('diagnose', () {
    test('Wi-Fi выключен: причина в нём', () async {
      access.wifiOn = false;
      expect(await readiness.diagnose(), NetworkProblem.wifiOff);
    });

    test('Wi-Fi включён на iOS: ОС не дала доступ к локальной сети', () async {
      access.asksLocalNetworkPermission = true;
      expect(await readiness.diagnose(), NetworkProblem.localNetworkDenied);
    });

    test('Wi-Fi включён на Android: точнее общего отказа сказать нельзя', () async {
      expect(await readiness.diagnose(), isNull);
    });
  });

  test('настройки открываются те, где проблему можно исправить', () async {
    await readiness.openSettings(NetworkProblem.wifiOff);
    await readiness.openSettings(NetworkProblem.localNetworkDenied);
    await readiness.openSettings(NetworkProblem.localNetworkExplainer);
    await readiness.openAppSettings();

    expect(access.openedSettings, ['wifi', 'app', 'app', 'app']);
  });
}
