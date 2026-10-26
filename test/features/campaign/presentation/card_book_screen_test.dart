import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/load_card_book.dart';
import 'package:gwent/src/features/campaign/domain/card_book.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_texts.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_screen.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_section_screen.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadCampaign campaign;
  late CampaignData data;
  late AppLocalizations l10n;
  late InMemoryCollectionRepository collection;

  setUpAll(() async {
    await loadDesignFonts();
    campaign = LoadCampaign(LoadGameContent(AssetContentSource.basePack(rootBundle)));
    data = (await campaign())!;
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  setUp(() => collection = InMemoryCollectionRepository());

  Future<void> pumpBook(WidgetTester tester, Widget screen) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = CardBookCubit(LoadCardBook(campaign, collection));
    addTearDown(() => unawaited(cubit.close()));
    await tester.pumpWidget(BlocProvider.value(value: cubit, child: localizedScreen(screen)));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('обзор: кольцо с нулём, строка у каждой фракции и общих карт, тап открывает раздел', (tester) async {
    final opened = <String>[];
    final book = (await tester.runAsync(LoadCardBook(campaign, collection).call))!.book;

    await pumpBook(tester, CardBookScreen(onBack: () {}, onOpenSection: opened.add));

    expect(find.text(l10n.campaignBookTitle), findsOneWidget);
    expect(find.text(l10n.campaignBookOutOf(book.total)), findsOneWidget);
    expect(find.text(l10n.campaignBookCommon), findsOneWidget);
    for (final section in book.sections.where((s) => s.fractionId != null)) {
      final fraction = data.pack.rules.fractionsById[section.fractionId]!;
      expect(find.text(data.text(fraction.nameKey)), findsOneWidget);
    }
    expectNoFallbackTextStyle(tester);
    expectBackButtonAtEdge(tester);

    await tester.tap(find.text(l10n.campaignBookCommon));
    expect(opened, [CardBook.commonId]);
  });

  testWidgets('раздел: открытая карта с лицом и копиями, закрытые силуэтами без имён', (tester) async {
    final first = (await tester.runAsync(LoadCardBook(campaign, collection).call))!.book.sections.first;
    final open = first.squads.firstWhere((card) => card.total > 1);
    final closed = first.squads.firstWhere((card) => card.cardId != open.cardId);
    await tester.runAsync(() => collection.grant({open.cardId: 1}));

    await pumpBook(tester, CardBookSectionScreen(sectionId: first.id, onBack: () {}));

    expect(
      find.byWidgetPredicate((w) => w is GwentCard && w.face is! CardBackFace),
      findsWidgets,
      reason: 'открытая карта показана с лицом',
    );
    expect(find.text('1/${open.total}'), findsOneWidget);
    expect(find.text('?'), findsWidgets, reason: 'закрытые карты силуэтами');
    expect(find.text(closed.name), findsNothing, reason: 'имя закрытой карты не показывается');
    expectNoFallbackTextStyle(tester);
    expectBackButtonAtEdge(tester);
  });

  testWidgets('раздел: вкладка «Лидеры» показывает лидеров фракции, у общих карт её нет', (tester) async {
    final book = (await tester.runAsync(LoadCardBook(campaign, collection).call))!.book;

    await pumpBook(tester, CardBookSectionScreen(sectionId: book.sections.first.id, onBack: () {}));
    await tester.tap(find.text(l10n.campaignBookTabLeaders));
    await tester.pump();

    expect(find.text(l10n.rewardKindLabel(RewardKind.leader).toUpperCase()), findsWidgets);

    await pumpBook(tester, CardBookSectionScreen(sectionId: CardBook.commonId, onBack: () {}));
    expect(find.text(l10n.campaignBookTabLeaders), findsNothing);
  });
}
