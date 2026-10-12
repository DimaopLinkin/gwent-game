import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/player_plate.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

PlayerPlate _plate({
  String name = 'Вы',
  PlayerPlateStatus status = PlayerPlateStatus.idle,
  GwentFaction faction = GwentFaction.northernRealms,
}) => PlayerPlate(
  name: name,
  factionName: 'Королевства Севера',
  faction: faction,
  handCount: 6,
  lifeRemaining: 2,
  score: 33,
  status: status,
);

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('занимает всю ширину 358 pt и не ниже 68 pt', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(alignment: Alignment.topCenter, child: _plate()),
        ),
      ),
    );
    final size = tester.getSize(find.byType(PlayerPlate));
    expect(size.width, 358);
    expect(size.height, greaterThanOrEqualTo(68));
    expect(tester.takeException(), isNull);
  });

  testWidgets('метка состояния: «Ваш ход» у активного, «Пас» у спасовавшего, у остальных нет', (tester) async {
    await tester.pumpWidget(localizedApp(_plate()));
    expect(find.text('Ваш ход'), findsNothing);
    expect(find.text('Пас'), findsNothing);

    await tester.pumpWidget(localizedApp(_plate(status: PlayerPlateStatus.active)));
    expect(find.text('Ваш ход'), findsOneWidget);

    await tester.pumpWidget(localizedApp(_plate(status: PlayerPlateStatus.passed)));
    expect(find.text('Пас'), findsOneWidget);
  });

  testWidgets('длинное имя в одну строку с многоточием, без переполнения на 320 pt', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: _plate(name: 'Очень длинное имя соперника из сетевой игры', status: PlayerPlateStatus.passed),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final name = tester.widget<Text>(find.text('Очень длинное имя соперника из сетевой игры'));
    expect((name.maxLines, name.overflow), (1, TextOverflow.ellipsis));
  });

  testWidgets('нейтральная фракция без герба тоже рисуется', (tester) async {
    await tester.pumpWidget(localizedApp(_plate(faction: GwentFaction.neutral)));
    expect(tester.takeException(), isNull);
  });
}
