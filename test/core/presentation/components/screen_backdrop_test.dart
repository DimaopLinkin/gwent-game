import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const screen = Size(390, 844);
  const insets = EdgeInsets.only(top: 59, bottom: 34);

  Future<void> pumpBackdrop(WidgetTester tester, {bool safeArea = true}) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: screen, padding: insets),
          child: ScreenBackdrop(
            safeArea: safeArea,
            child: const SizedBox.expand(key: Key('content')),
          ),
        ),
      ),
    );
  }

  testWidgets('фон занимает весь экран, содержимое лежит в безопасной области', (tester) async {
    await pumpBackdrop(tester);
    expect(tester.getRect(find.byType(ScreenBackdrop)), Offset.zero & screen);
    expect(tester.getRect(find.byKey(const Key('content'))), const Rect.fromLTRB(0, 59, 390, 844 - 34));
  });

  testWidgets('без safeArea содержимое тоже занимает весь экран', (tester) async {
    await pumpBackdrop(tester, safeArea: false);
    expect(tester.getRect(find.byKey(const Key('content'))), Offset.zero & screen);
  });
}
