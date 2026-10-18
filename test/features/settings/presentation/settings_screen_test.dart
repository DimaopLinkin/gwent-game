import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/gwent_slider.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/settings/application/check_content_update.dart';
import 'package:gwent/src/features/settings/application/load_about_info.dart';
import 'package:gwent/src/features/settings/application/save_settings.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/presentation/settings_cubit.dart';
import 'package:gwent/src/features/settings/presentation/settings_screen.dart';
import 'package:gwent/src/features/settings/presentation/settings_state.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySettingsRepository repository;
  late AppLocalizations l10n;
  late List<String> taps;

  setUpAll(loadDesignFonts);

  setUp(() async {
    repository = InMemorySettingsRepository();
    taps = [];
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  Future<void> pumpSettings(WidgetTester tester, {Duration minCheck = Duration.zero}) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Держатель создаётся и дочитывает настройки и набор карт из ассетов настоящим временем, вне фальшивых часов.
    final cubit = (await tester.runAsync(() async {
      final content = LoadGameContent(AssetContentSource.basePack(rootBundle));
      final cubit = SettingsCubit(
        watchSettings: WatchSettings(repository),
        saveSettings: SaveSettings(repository),
        loadAboutInfo: LoadAboutInfo(const FakeAppInfo('1.2.3', '45'), content),
        checkContentUpdate: CheckContentUpdate(content, FakeClock(DateTime.utc(2026, 10, 13, 12))),
        minCheckDuration: minCheck,
      );
      await cubit.stream.firstWhere((state) => state is SettingsLoaded).timeout(const Duration(seconds: 20));
      return cubit;
    }))!;
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: localizedApp(
          SettingsScreen(onBack: () => taps.add('back'), onLicenses: () => taps.add('licenses')),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('пять групп и версии: приложение, сборка, протокол, набор карт', (tester) async {
    await pumpSettings(tester);

    for (final title in [
      l10n.settingsGroupGame,
      l10n.settingsGroupSound,
      l10n.settingsGroupLanguage,
      l10n.settingsGroupContent,
      l10n.settingsGroupAbout,
    ]) {
      expect(find.text(title.toUpperCase()), findsOneWidget, reason: title);
    }
    expect(find.text(l10n.settingsAppVersionBuild('1.2.3', '45')), findsOneWidget);
    expect(find.text(l10n.settingsProtocolValue(1)), findsOneWidget);
    expect(find.text(l10n.settingsFanProject), findsOneWidget);
    expect(find.text(l10n.settingsValueUnknown), findsOneWidget, reason: 'дата проверки: пока не проверяли');
  });

  testWidgets('значения по умолчанию в элементах', (tester) async {
    await pumpSettings(tester);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.map((s) => s.value), [true, true]);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('переключатели и скорость анимаций сохраняются', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.tap(find.text(l10n.settingsHints));
    await tester.tap(find.text(l10n.settingsSpeedFast));
    await tester.pump();

    expect(repository.saved.confirmPass, isFalse);
    expect(repository.saved.hints, isFalse);
    expect(repository.saved.animationSpeed, AnimationSpeed.fast);
    expect(tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value), [false, false]);
  });

  testWidgets('имя игрока вводится, обрезается до 20 символов и сохраняется без пробелов по краям', (tester) async {
    repository.saved = const AppSettings(playerName: 'Геральт');
    await pumpSettings(tester);
    expect(find.widgetWithText(TextField, 'Геральт'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Йеннифэр из Венгерберга и Цинтры ');
    await tester.pump();

    final saved = repository.saved.playerName!;
    expect(saved.length, lessThanOrEqualTo(20));
    expect(saved, startsWith('Йеннифэр'));
    expect(saved, saved.trim());
  });

  testWidgets('громкость сохраняется, когда ползунок отпущен', (tester) async {
    await pumpSettings(tester);

    await tester.drag(find.byType(GwentSlider).first, const Offset(-200, 0));
    await tester.pump();

    expect(repository.saved.musicVolume, lessThan(70));
    expect(find.text('${repository.saved.musicVolume}%'), findsOneWidget);
  });

  testWidgets('английский, польский и сервер недоступны', (tester) async {
    await pumpSettings(tester);

    expect(find.text(l10n.settingsSoon), findsNWidgets(2));
    final server = tester.widget<GwentButton>(find.widgetWithText(GwentButton, l10n.settingsSourceServer));
    expect(server.onPressed, isNull);
    final builtIn = tester.widget<GwentButton>(find.widgetWithText(GwentButton, l10n.settingsSourceBuiltIn));
    expect(builtIn.style, GwentButtonStyle.primary);
  });

  testWidgets('проверка обновления: кнопка гаснет, потом набор актуален и появляется дата', (tester) async {
    await pumpSettings(tester, minCheck: const Duration(milliseconds: 500));
    GwentButton button() => tester.widget(find.widgetWithText(GwentButton, l10n.settingsCheckUpdate));
    expect(button().onPressed, isNotNull);

    await tester.tap(find.text(l10n.settingsCheckUpdate));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Набор уже загружен в настоящем времени: его ответ приходит вне фальшивых часов.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));

    expect(find.text(l10n.settingsChecking), findsOneWidget);
    expect(button().onPressed, isNull, reason: 'пока идёт проверка, кнопка погашена');

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text(l10n.settingsChecking), findsNothing);
    expect(find.text(l10n.settingsUpToDate), findsOneWidget);
    expect(button().onPressed, isNotNull);
    expect(find.text('13.10.2026'), findsOneWidget);
    expect(repository.saved.contentCheckedAt, DateTime.utc(2026, 10, 13, 12));
  });

  testWidgets('«назад» и лицензии отдают переходы наружу', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(ChevronButton));
    await tester.ensureVisible(find.text(l10n.settingsLicenses));
    await tester.tap(find.text(l10n.settingsLicenses));

    expect(taps, ['back', 'licenses']);
  });
}
