import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  Future<void> pumpHeader(WidgetTester tester, ScreenHeader header, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(Column(children: [header])));
  }

  testWidgets('стрелка у левого края с полем 16 pt и у верха шапки, зона нажатия 44 pt', (tester) async {
    await pumpHeader(
      tester,
      ScreenHeader(eyebrow: 'Шаг 2 из 2', title: 'Выбор лидера', subtitle: 'Скеллиге', onBack: () {}),
    );

    final back = tester.getRect(find.byType(ChevronButton));
    expect(back.left, ScreenHeader.inset);
    expect(back.top, ScreenHeader.topMargin);
    expect(back.size, const Size.square(44));
  });

  testWidgets('надпись в две строки не сдвигает стрелку: она остаётся у верха шапки', (tester) async {
    await pumpHeader(
      tester,
      ScreenHeader(eyebrow: 'Игрок 1 · шаг 2 из 2, выбор фракции для партии', title: 'Выбор', onBack: () {}),
      size: const Size(320, 640),
    );

    expect(tester.getSize(find.byType(ScreenHeader)).height, greaterThan(ScreenHeader.topMargin + 44));
    expect(tester.getTopLeft(find.byType(ChevronButton)), const Offset(ScreenHeader.inset, ScreenHeader.topMargin));
    expect(tester.takeException(), isNull);
  });

  testWidgets('поле стрелки не зависит от длины заголовка и ширины экрана', (tester) async {
    await pumpHeader(
      tester,
      ScreenHeader(eyebrow: 'Шаг 1 из 2', title: 'Очень длинный заголовок экрана выбора', onBack: () {}),
      size: const Size(320, 640),
    );

    expect(tester.getRect(find.byType(ChevronButton)).left, ScreenHeader.inset);
    expect(tester.takeException(), isNull, reason: 'длинный заголовок сжимается, а не переполняет шапку');
  });

  testWidgets('надпись и заголовок по центру экрана, даже когда справа нет ничего', (tester) async {
    await pumpHeader(tester, ScreenHeader(eyebrow: 'Колоды', title: 'Мои колоды', onBack: () {}));

    expect(tester.getCenter(find.text('Мои колоды')).dx, closeTo(195, 0.5));
    expect(tester.getCenter(find.text('КОЛОДЫ')).dx, closeTo(195, 0.5));
  });

  testWidgets('справа ставится [trailing] с тем же полем, а центр не сдвигается', (tester) async {
    await pumpHeader(
      tester,
      ScreenHeader(
        title: 'Выбор лидера',
        onBack: () {},
        trailing: const SizedBox.square(key: ValueKey('crest'), dimension: 40),
      ),
    );

    final crest = tester.getRect(find.byKey(const ValueKey('crest')));
    expect(crest.right, 390 - ScreenHeader.inset);
    expect(tester.getCenter(find.text('Выбор лидера')).dx, closeTo(195, 0.5));
  });

  testWidgets('нажатие зовёт onBack; подпись для диктора по умолчанию «Назад», её можно заменить', (tester) async {
    final handle = tester.ensureSemantics();
    var backs = 0;
    await pumpHeader(tester, ScreenHeader(title: 'Заголовок', onBack: () => backs++));
    expect(find.bySemanticsLabel(l10n.setupBack), findsOneWidget);
    await tester.tap(find.byType(ChevronButton));
    expect(backs, 1);

    await pumpHeader(tester, ScreenHeader(title: 'Заголовок', backLabel: 'Колоды', onBack: () => backs++));
    expect(find.bySemanticsLabel('Колоды'), findsOneWidget);
    handle.dispose();
  });
}
