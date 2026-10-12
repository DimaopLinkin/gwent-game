import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/filter_tabs.dart';
import 'package:gwent/src/core/presentation/components/row_weather_overlay.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';

import '../../../support/localized_app.dart';

void main() {
  group('вкладки-фильтры', () {
    const tabs = [
      FilterTabData(label: 'Ближний', icon: GwentIcon.rowMelee, count: 12),
      FilterTabData(label: 'Дальний', icon: GwentIcon.rowRanged, count: 9),
      FilterTabData(label: 'Погода', icon: GwentIcon.weatherFrost, count: 0),
      FilterTabData(label: 'Все', icon: GwentIcon.iconDeck),
    ];

    testWidgets('вкладка не ниже 44 pt, выбор вызывает колбэк с номером', (tester) async {
      int? selected;
      await tester.pumpWidget(
        localizedApp(FilterTabs(tabs: tabs, selectedIndex: 0, onSelected: (index) => selected = index)),
      );
      expect(tester.getSize(find.text('Дальний')).height, lessThan(44));
      expect(
        tester.getRect(find.ancestor(of: find.text('Дальний'), matching: find.byType(GestureDetector)).first).height,
        44,
      );
      await tester.tap(find.text('Дальний'));
      expect(selected, 1);
    });

    testWidgets('вкладка с нулём карт недоступна: тап не выбирает', (tester) async {
      int? selected;
      await tester.pumpWidget(
        localizedApp(FilterTabs(tabs: tabs, selectedIndex: 0, onSelected: (index) => selected = index)),
      );
      await tester.tap(find.text('Погода'));
      expect(selected, isNull);
    });

    testWidgets('скринридер слышит название, число и выбранность', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(localizedApp(FilterTabs(tabs: tabs, selectedIndex: 0, onSelected: (_) {})));
      final node = find.semantics.byLabel('Ближний, 12').evaluate().single;
      expect(node.getSemanticsData().flagsCollection.isSelected.toBoolOrNull(), isTrue);
      semantics.dispose();
    });

    testWidgets('много вкладок на узком экране прокручиваются без переполнения', (tester) async {
      tester.view.physicalSize = const Size(200, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(localizedApp(FilterTabs(tabs: tabs, selectedIndex: 0, onSelected: (_) {})));
      expect(tester.takeException(), isNull);
    });
  });

  group('погода на ряду', () {
    Future<void> pump(WidgetTester tester, GwentWeather? weather, {bool reduceMotion = false}) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: localizedApp(SizedBox(width: 300, height: 88, child: RowWeatherOverlay(weather: weather))),
      ),
    );

    testWidgets('иней, туман и дождь рисуются без ошибок', (tester) async {
      for (final weather in [GwentWeather.frost, GwentWeather.fog, GwentWeather.rain]) {
        await pump(tester, weather);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CustomPaint), findsWidgets, reason: '$weather');
        expect(tester.takeException(), isNull, reason: '$weather');
      }
    });

    testWidgets('слой не принимает касаний', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        localizedApp(
          Stack(
            children: [
              GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox.expand()),
              const RowWeatherOverlay(weather: GwentWeather.rain),
            ],
          ),
        ),
      );
      await tester.tapAt(const Offset(100, 100));
      expect(taps, 1);
    });

    testWidgets('без погоды слой пуст; шторм и ясное небо оверлея не рисуют', (tester) async {
      for (final weather in [null, GwentWeather.skelligeStorm, GwentWeather.clear]) {
        await pump(tester, weather);
        expect(
          find
              .byType(CustomPaint)
              .evaluate()
              .where((e) => e.widget is CustomPaint && (e.widget as CustomPaint).painter != null),
          isEmpty,
          reason: '$weather',
        );
      }
    });

    testWidgets('ясное небо: оверлей гаснет за 400 мс', (tester) async {
      await pump(tester, GwentWeather.frost);
      await pump(tester, GwentWeather.clear);
      await tester.pump(const Duration(milliseconds: 200));
      final halfway = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      expect(halfway, 0);
      await tester.pump(RowWeatherOverlay.fadeDuration);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);
    });

    testWidgets('при «уменьшить движение» туман и дождь статичны', (tester) async {
      await pump(tester, GwentWeather.fog, reduceMotion: true);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      await pump(tester, GwentWeather.rain);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });
}
