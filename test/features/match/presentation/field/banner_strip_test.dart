import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/features/match/presentation/field/banner_layer.dart';

import '../../../../support/fonts.dart';
import '../../../../support/localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadDesignFonts);

  /// Ширины экранов в pt: iPhone 14 Pro, iPhone SE и совсем узкий запас.
  const widths = [393.0, 375.0, 320.0, 280.0];
  const titles = ['Победа', 'Поражение', 'Ничья', 'Победил Игрок номер два'];

  for (final weight in BannerWeight.values) {
    for (final width in widths) {
      testWidgets('заголовок плашки «${weight.name}» не переносится на экране $width pt', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final title in titles) {
          await tester.pumpWidget(
            localizedApp(
              MatchBannerStrip(
                weight: weight,
                title: title,
                titleColor: GwentColors.goldHighlight,
                ruleColor: GwentColors.gold,
              ),
            ),
          );
          final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
          final style = paragraph.text.style!;
          final lineHeight = style.fontSize! * style.height!;
          expect(
            paragraph.size.height,
            lessThan(lineHeight * 1.5),
            reason: '«$title» должен стоять в одну строку на $width pt',
          );
          final box = tester.getRect(find.text(title));
          expect(box.left, greaterThanOrEqualTo(0), reason: '«$title» не выходит за левый край');
          expect(box.right, lessThanOrEqualTo(width), reason: '«$title» не выходит за правый край');
        }
      });
    }
  }
}
