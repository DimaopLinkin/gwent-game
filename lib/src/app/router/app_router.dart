import 'dart:async';

import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/app/router/app_routes.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_deck_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_deck_screen.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_match_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_match_screen.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_screen.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_widgets.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_screen.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_section_screen.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_screen.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_screen.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_topic.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_cubit.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_screen.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_topic_screen.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_screen.dart';
import 'package:gwent/src/features/lobby/presentation/create_online_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/create_online_game_screen.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_screen.dart';
import 'package:gwent/src/features/lobby/presentation/host_invite_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/host_qr_screen.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_screen.dart';
import 'package:gwent/src/features/lobby/presentation/lobby_builder_screen.dart';
import 'package:gwent/src/features/lobby/presentation/lobby_deck_picker_screen.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_indicator.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_layer.dart';
import 'package:gwent/src/features/lobby/presentation/play_method_screen.dart';
import 'package:gwent/src/features/lobby/presentation/qr_scan_screen.dart';
import 'package:gwent/src/features/lobby/presentation/room_code_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_screen.dart';
import 'package:gwent/src/features/match/domain/match_session.dart' show LocalMatchMode;
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent/src/features/match_history/presentation/history_cubit.dart';
import 'package:gwent/src/features/match_history/presentation/history_screen.dart';
import 'package:gwent/src/features/menu/presentation/menu_screen.dart';
import 'package:gwent/src/features/replay/presentation/replay_cubit.dart';
import 'package:gwent/src/features/replay/presentation/replay_screen.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/presentation/settings_cubit.dart';
import 'package:gwent/src/features/settings/presentation/settings_screen.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_cubit.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_screen.dart';
import 'package:gwent_engine/gwent_engine.dart' show Resign;

/// Навигация приложения.
///
/// Здесь экраны получают держатели состояния (с нужными сценариями из [dependencies]) и переходы. Сами экраны
/// не знают ни о маршрутах, ни о других фичах, ни о том, откуда берутся сценарии.
GoRouter createAppRouter(AppDependencies dependencies) => GoRouter(
  initialLocation: AppRoutes.menu,
  routes: [
    GoRoute(
      path: AppRoutes.menu,
      builder: (context, state) => MenuScreen(
        onHotSeat: () => context.go(AppRoutes.matchHotSeat),
        onBot: () => context.go(AppRoutes.matchBot),
        onNetworkGame: () => context.go(AppRoutes.play),
        onDecks: () => context.go(AppRoutes.decks),
        onHistory: () => context.go(AppRoutes.history),
        onTutorial: () => context.go(AppRoutes.tutorial),
        onSettings: () => context.go(AppRoutes.settings),
        onCampaign: () => context.go(AppRoutes.campaign),
      ),
      routes: [
        GoRoute(
          path: _child(AppRoutes.campaign),
          builder: (context, state) => BlocProvider(
            create: (_) => CampaignCubit(
              dependencies.watchCampaignPath,
              dependencies.loadCampaignOverview,
              dependencies.claimStartingSet,
              dependencies.syncCampaignRewards,
            ),
            child: CampaignScreen(
              openNodeId: state.uri.queryParameters[AppRoutes.campaignOpenParam],
              onBack: () => context.go(AppRoutes.menu),
              onPlay: (nodeId) => context.go(AppRoutes.campaignPlay(nodeId)),
              onFirstMatch: () => context.go(AppRoutes.tutorialFromCampaign),
              onPickDeck: (nodeId) =>
                  context.push<void>(nodeId == null ? AppRoutes.campaignDecks : AppRoutes.campaignDecksFor(nodeId)),
              onBuildDeck: () => context.push<void>(AppRoutes.campaignDeckNew),
              onBook: () => context.push<void>(AppRoutes.campaignBook),
            ),
          ),
          routes: [
            GoRoute(
              path: 'decks',
              builder: (context, state) => BlocProvider(
                // Страница одна на все узлы (ключ по шаблону пути): без ключа держатель остался бы от прежнего узла.
                key: ValueKey(state.uri.queryParameters[AppRoutes.campaignNodeParam]),
                create: (_) => CampaignDeckCubit(
                  dependencies.listCampaignDecks,
                  dependencies.getCampaignDeck,
                  dependencies.chooseCampaignDeck,
                  dependencies.loadCampaign,
                  nodeId: state.uri.queryParameters[AppRoutes.campaignNodeParam],
                ),
                child: CampaignDeckScreen(
                  onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.campaign),
                  onBattle: (nodeId) => context.go(AppRoutes.campaignPlay(nodeId)),
                  onChosen: () => context.canPop() ? context.pop() : context.go(AppRoutes.campaign),
                  onBuild: () => context.push<void>(AppRoutes.campaignDeckNew),
                  onEdit: (deckId) => context.push<void>(AppRoutes.campaignDeckEdit(deckId)),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => _campaignDeckEditor(context, dependencies),
                ),
                GoRoute(
                  path: ':${AppRoutes.campaignDeckIdParam}',
                  builder: (context, state) {
                    final deckId = state.pathParameters[AppRoutes.campaignDeckIdParam]!;
                    // Страница одна на все колоды (ключ по шаблону пути): ключ даёт каждой колоде свой конструктор.
                    return _campaignDeckEditor(context, dependencies, deckId: deckId, key: ValueKey(deckId));
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'book',
              builder: (context, state) => BlocProvider(
                create: (_) => CardBookCubit(dependencies.loadCardBook),
                child: CardBookScreen(
                  onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.campaign),
                  onOpenSection: (sectionId) => context.push<void>(AppRoutes.campaignBookSection(sectionId)),
                ),
              ),
              routes: [
                GoRoute(
                  path: ':${AppRoutes.campaignBookSectionParam}',
                  builder: (context, state) => BlocProvider(
                    // Страница одна на все разделы (ключ по шаблону пути): ключ сбрасывает вкладку прежнего раздела.
                    key: ValueKey(state.pathParameters[AppRoutes.campaignBookSectionParam]),
                    create: (_) => CardBookCubit(dependencies.loadCardBook),
                    child: CardBookSectionScreen(
                      sectionId: state.pathParameters[AppRoutes.campaignBookSectionParam]!,
                      onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.campaignBook),
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'play/:${AppRoutes.campaignNodeIdParam}',
              builder: (context, state) =>
                  _campaignMatch(context, dependencies, state.pathParameters[AppRoutes.campaignNodeIdParam]!),
            ),
          ],
        ),
        GoRoute(
          path: _child(AppRoutes.history),
          builder: (context, state) => BlocProvider(
            create: (_) => HistoryCubit(dependencies.watchMatchHistory, dependencies.loadDeckRules),
            child: HistoryScreen(
              onOpen: (recordId) => context.go(AppRoutes.replay(recordId)),
              onBack: () => context.go(AppRoutes.menu),
            ),
          ),
          routes: [
            GoRoute(
              path: ':${AppRoutes.replayIdParam}',
              builder: (context, state) => BlocProvider(
                create: (_) => ReplayCubit(dependencies.loadReplay, state.pathParameters[AppRoutes.replayIdParam]!),
                child: StreamBuilder<AppSettings>(
                  stream: dependencies.watchSettings(),
                  initialData: const AppSettings(),
                  builder: (context, snapshot) => ReplayScreen(
                    onExit: () => context.go(AppRoutes.history),
                    sound: dependencies.playSound,
                    animationScale: switch ((snapshot.data ?? const AppSettings()).animationSpeed) {
                      AnimationSpeed.normal => 1,
                      AnimationSpeed.fast => StageTokens.fastFactor,
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: _child(AppRoutes.decks),
          builder: (context, state) => BlocProvider(
            create: (_) => DeckListCubit(dependencies.watchDecks, dependencies.loadDeckRules, dependencies.deleteDeck),
            child: DeckListScreen(
              onOpen: (deckId) => context.go(AppRoutes.deckEdit(deckId)),
              onNew: () => context.go(AppRoutes.deckNew),
              onBack: () => context.go(AppRoutes.menu),
            ),
          ),
          routes: [
            // `new` раньше `:id`, иначе путь новой колоды разобрался бы как колода с идентификатором `new`.
            GoRoute(
              path: 'new',
              builder: (context, state) => _deckEditor(context, dependencies),
            ),
            GoRoute(
              path: ':${AppRoutes.deckIdParam}',
              builder: (context, state) =>
                  _deckEditor(context, dependencies, deckId: state.pathParameters[AppRoutes.deckIdParam]),
            ),
          ],
        ),
        GoRoute(
          path: _child(AppRoutes.play),
          builder: (context, state) => PlayMethodScreen(
            initial: state.uri.queryParameters[AppRoutes.playMethodParam] == AppRoutes.playMethodInternet
                ? PlayMethod.internet
                : PlayMethod.wifi,
            onCreate: (method) => context.go(switch (method) {
              PlayMethod.wifi => AppRoutes.playCreate,
              PlayMethod.internet => AppRoutes.playOnlineCreate,
            }),
            onFind: (method) => context.go(switch (method) {
              PlayMethod.wifi => AppRoutes.playFind,
              PlayMethod.internet => AppRoutes.playOnlineJoin,
            }),
            onBack: () => context.go(AppRoutes.menu),
          ),
          routes: [
            GoRoute(
              path: 'online/create',
              builder: (context, state) => BlocProvider(
                create: (_) => CreateOnlineGameCubit(
                  dependencies.hostOnlineGame,
                  dependencies.watchSettings,
                  fallbackName: context.l10n.playerPlateYou,
                ),
                child: CreateOnlineGameScreen(
                  onCreated: () => context.go(AppRoutes.playRoom),
                  onBack: () => context.go(AppRoutes.playInternet),
                ),
              ),
            ),
            GoRoute(
              path: 'online/join',
              builder: (context, state) => BlocProvider(
                create: (_) => JoinOnlineGameCubit(
                  dependencies.joinOnlineGame,
                  dependencies.watchSettings,
                  fallbackName: context.l10n.playerPlateYou,
                ),
                child: JoinOnlineGameScreen(
                  onJoined: () => context.go(AppRoutes.playRoom),
                  onBack: () => context.go(AppRoutes.playInternet),
                ),
              ),
            ),
            GoRoute(
              path: 'create',
              builder: (context, state) => BlocProvider(
                create: (_) => CreateGameCubit(
                  dependencies.hostNetworkGame,
                  dependencies.watchSettings,
                  dependencies.networkReadiness,
                  fallbackName: context.l10n.playerPlateYou,
                ),
                child: CreateGameScreen(
                  onCreated: () => context.go(AppRoutes.playRoom),
                  onBack: () => context.go(AppRoutes.play),
                ),
              ),
            ),
            GoRoute(
              path: 'find',
              builder: (context, state) => BlocProvider(
                create: (_) => FindGamesCubit(
                  dependencies.discoverNetworkGames,
                  dependencies.joinNetworkGame,
                  dependencies.watchSettings,
                  dependencies.networkReadiness,
                  fallbackName: context.l10n.playerPlateYou,
                ),
                child: FindGamesScreen(
                  onJoined: () => context.go(AppRoutes.playRoom),
                  onScan: () => context.push<GameAddress>(AppRoutes.playFindScan),
                  onBack: () => context.go(AppRoutes.play),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'scan',
                  builder: (context, state) => QrScanScreen(
                    onInvite: (address) => context.pop(address),
                    onOpenSettings: () => unawaited(dependencies.networkReadiness.openAppSettings()),
                    onBack: () => context.pop(),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'room',
              // Комната без игры (например, после перезапуска) — это уже не комната.
              redirect: (context, state) => dependencies.activeNetworkGame.current == null ? AppRoutes.play : null,
              builder: (context, state) {
                final game = dependencies.activeNetworkGame.current!;
                final online = game.isOnline;
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(create: (_) => RoomCubit(game, dependencies.loadDeckRules, dependencies.getDeck)),
                    // Код комнаты нужен только хосту игры через интернет.
                    if (online && game.isHost) BlocProvider(create: (_) => RoomCodeCubit(game)),
                  ],
                  child: RoomScreen(
                    isHost: game.isHost,
                    online: online,
                    title: game.title ?? '',
                    onPickDeck: (deckId) => context.push<String>(AppRoutes.playRoomDecks, extra: deckId),
                    onBuildDeck: (deckId) => context.push<String>(
                      deckId == null ? AppRoutes.playRoomBuild : AppRoutes.playRoomBuildDeck(deckId),
                    ),
                    onShowQr: () => context.push(AppRoutes.playRoomQr),
                    onStarted: () => context.go(AppRoutes.playMatch),
                    onLeft: () => context.go(online ? AppRoutes.playInternet : AppRoutes.play),
                  ),
                );
              },
              routes: [
                GoRoute(
                  path: 'qr',
                  // Код показывает только хост, пока партия жива.
                  redirect: (context, state) {
                    final game = dependencies.activeNetworkGame.current;
                    return game != null && game.isHost ? null : AppRoutes.play;
                  },
                  builder: (context, state) => BlocProvider(
                    create: (_) => HostInviteCubit(dependencies.activeNetworkGame.current!),
                    child: HostQrScreen(onBack: () => context.pop()),
                  ),
                ),
                GoRoute(
                  path: 'decks',
                  builder: (context, state) => BlocProvider(
                    create: (_) =>
                        DeckListCubit(dependencies.watchDecks, dependencies.loadDeckRules, dependencies.deleteDeck),
                    child: LobbyDeckPickerScreen(
                      initialDeckId: state.extra as String?,
                      onSelect: (deckId) => context.pop(deckId),
                      onBuildNew: () async {
                        final deckId = await context.push<String>(AppRoutes.playRoomBuild);
                        if (deckId != null && context.mounted) context.pop(deckId);
                      },
                      onBack: () => context.pop(),
                    ),
                  ),
                ),
                GoRoute(path: 'build', builder: (context, state) => _lobbyBuilder(context, dependencies)),
                GoRoute(
                  path: 'build/:${AppRoutes.deckIdParam}',
                  builder: (context, state) =>
                      _lobbyBuilder(context, dependencies, deckId: state.pathParameters[AppRoutes.deckIdParam]),
                ),
              ],
            ),
            GoRoute(
              path: 'match',
              // Сетевая партия открывается только из комнаты, когда хост её начал.
              redirect: (context, state) {
                final game = dependencies.activeNetworkGame.current;
                return game != null && game.room.started && !game.handedOver ? null : AppRoutes.menu;
              },
              builder: (context, state) => _networkMatch(context, dependencies),
            ),
          ],
        ),
        GoRoute(
          path: _child(AppRoutes.settings),
          builder: (context, state) {
            final overGame = state.uri.queryParameters[AppRoutes.overGameParam] == '1';
            return BlocProvider(
              create: (_) => SettingsCubit(
                watchSettings: dependencies.watchSettings,
                saveSettings: dependencies.saveSettings,
                loadAboutInfo: dependencies.loadAboutInfo,
                checkContentUpdate: dependencies.checkContentUpdate,
                sound: dependencies.playSound,
                haptic: dependencies.playHaptic,
              ),
              child: SettingsScreen(
                // Из партии настройки открывают поверх неё (push), оттуда возвращаются назад, а не в меню.
                onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.menu),
                onLicenses: () => showLicensePage(context: context, applicationName: context.l10n.appTitle),
                onHowToPlay: () => context.push(AppRoutes.howToPlay(overGame: overGame)),
                // Поверх партии «Первую партию» не запускают: она оборвала бы идущую игру.
                onTutorial: overGame ? null : () => context.go(AppRoutes.tutorial),
                // Поверх партии кампанию не сбрасывают: стёртый прогресс оборвал бы партию узла.
                onResetCampaign: overGame ? null : () => dependencies.resetCampaign(),
              ),
            );
          },
        ),
        GoRoute(
          path: _child(AppRoutes.howToPlayPath),
          builder: (context, state) {
            final overGame = state.uri.queryParameters[AppRoutes.overGameParam] == '1';
            return HowToPlayScreen(
              onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.menu),
              onOpen: (topic) => context.push(AppRoutes.howToTopic(topic.key)),
              // Из партии справочник открывают поверх неё; «Первая партия» оборвала бы её.
              onTutorial: overGame ? null : () => context.go(AppRoutes.tutorial),
            );
          },
          routes: [
            GoRoute(
              path: ':${AppRoutes.howToTopicParam}',
              redirect: (context, state) => HowToTopic.fromKey(state.pathParameters[AppRoutes.howToTopicParam]!) == null
                  ? AppRoutes.howToPlay()
                  : null,
              builder: (context, state) {
                final topic = HowToTopic.fromKey(state.pathParameters[AppRoutes.howToTopicParam]!)!;
                return BlocProvider(
                  create: (_) => HowToPlayCubit(dependencies.loadGameContent),
                  child: HowToTopicScreen(
                    topic: topic,
                    onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.howToPlay()),
                    onOpen: (next) => context.pushReplacement(AppRoutes.howToTopic(next.key)),
                  ),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: _child(AppRoutes.tutorial),
          builder: (context, state) {
            final fromCampaign = state.uri.queryParameters[AppRoutes.fromCampaignParam] == '1';
            return BlocProvider(
              create: (_) => FirstMatchCubit(
                dependencies.startFirstMatch,
                playerDeckName: context.l10n.tutorialPlayerDeckName,
                opponentDeckName: context.l10n.tutorialOpponentDeckName,
              ),
              child: StreamBuilder<AppSettings>(
                stream: dependencies.watchSettings(),
                initialData: const AppSettings(),
                builder: (context, snapshot) => FirstMatchScreen(
                  startMatch: dependencies.startMatch,
                  recordFinishedMatch: dependencies.recordFinishedMatch,
                  markPassed: dependencies.markFirstMatchPassed,
                  onExit: () => context.go(AppRoutes.menu),
                  // Миссия 0 кампании ведёт обратно на тропу, где игрок получает стартовый набор.
                  onPlayBot: () => context.go(fromCampaign ? AppRoutes.campaign : AppRoutes.matchBot),
                  playLabel: fromCampaign ? context.l10n.campaignContinueCampaign : null,
                  onSettings: () => context.push(AppRoutes.settingsOverGame),
                  onHowToPlay: () => context.push(AppRoutes.howToPlay(overGame: true)),
                  animationScale: switch ((snapshot.data ?? const AppSettings()).animationSpeed) {
                    AnimationSpeed.normal => 1,
                    AnimationSpeed.fast => StageTokens.fastFactor,
                  },
                  sound: dependencies.playSound,
                  haptic: dependencies.playHaptic,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: _child(AppRoutes.match),
          builder: (context, state) {
            final settings = dependencies.watchSettings();
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => MatchSetupCubit(
                    watchDecks: dependencies.watchDecks,
                    loadDeckRules: dependencies.loadDeckRules,
                    getActiveDeck: dependencies.getActiveDeck,
                    setActiveDeck: dependencies.setActiveDeck,
                    chooseOpponentDeck: dependencies.chooseOpponentDeck,
                    loadBotDifficulty: dependencies.loadBotDifficulty,
                    saveBotDifficulty: dependencies.saveBotDifficulty,
                    mode: _matchMode(state),
                  ),
                ),
                BlocProvider(create: (_) => MatchBloc(dependencies.startMatch, dependencies.recordFinishedMatch)),
                BlocProvider(
                  create: (_) => FieldCubit(sound: dependencies.playSound, haptic: dependencies.playHaptic),
                ),
              ],
              child: StreamBuilder<AppSettings>(
                stream: settings,
                initialData: const AppSettings(),
                builder: (context, snapshot) => MatchScreen(
                  onExit: () => context.go(AppRoutes.menu),
                  // Конструктор открывается поверх выбора, а не вместо него: после правки игрок возвращается к тому же шагу.
                  onEditDeck: (deckId) => context.push(AppRoutes.deckEdit(deckId)),
                  onSettings: () => context.push(AppRoutes.settingsOverGame),
                  onHowToPlay: () => context.push(AppRoutes.howToPlay(overGame: true)),
                  confirmPass: (snapshot.data ?? const AppSettings()).confirmPass,
                  hints: (snapshot.data ?? const AppSettings()).hints,
                  animationScale: switch ((snapshot.data ?? const AppSettings()).animationSpeed) {
                    AnimationSpeed.normal => 1,
                    AnimationSpeed.fast => StageTokens.fastFactor,
                  },
                ),
              ),
            );
          },
        ),
      ],
    ),
  ],
);

/// Конструктор колоды [deckId] или новой колоды, если [deckId] не задан. Выход (назад или после сохранения) возвращает
/// на экран, с которого его открыли.
Widget _deckEditor(BuildContext context, AppDependencies dependencies, {String? deckId}) => BlocProvider(
  create: (_) => DeckEditorCubit(
    loadDeckRules: dependencies.loadDeckRules,
    getDeck: dependencies.getDeck,
    saveDeck: dependencies.saveDeck,
    newDeckName: context.l10n.deckListNew,
    deckId: deckId,
    sound: dependencies.playSound,
  ),
  child: DeckEditorScreen(onExit: () => context.pop()),
);

/// Конструктор колоды в режиме кампании (ADR 0033): только открытые карты, плашка «Режим кампании». Закрывается
/// возвратом на экран, с которого его открыли.
Widget _campaignDeckEditor(BuildContext context, AppDependencies dependencies, {String? deckId, Key? key}) =>
    BlocProvider(
      key: key,
      create: (_) => DeckEditorCubit(
        loadDeckRules: dependencies.loadDeckRules,
        getDeck: dependencies.getDeck,
        saveDeck: dependencies.saveDeck,
        newDeckName: context.l10n.deckListNew,
        deckId: deckId,
        loadCollection: dependencies.loadCollection,
        sound: dependencies.playSound,
      ),
      child: DeckEditorScreen(
        onExit: () => context.canPop() ? context.pop() : context.go(AppRoutes.campaign),
        banner: const CampaignModeBanner(),
      ),
    );

/// Партия узла [nodeId] кампании: обычная партия против бота с итогом и наградой.
Widget _campaignMatch(BuildContext context, AppDependencies dependencies, String nodeId) => BlocProvider(
  // «Дальше» ведёт на тот же маршрут с другим узлом: страница остаётся прежней, и без ключа держатели остались бы от
  // прежнего узла.
  key: ValueKey(nodeId),
  create: (_) => CampaignMatchCubit(dependencies.prepareCampaignMatch, dependencies.loadCampaign, nodeId),
  child: StreamBuilder<AppSettings>(
    stream: dependencies.watchSettings(),
    initialData: const AppSettings(),
    builder: (context, snapshot) {
      final settings = snapshot.data ?? const AppSettings();
      return CampaignMatchScreen(
        startMatch: dependencies.startMatch,
        recordFinishedMatch: dependencies.recordFinishedMatch,
        onExit: () => context.go(AppRoutes.campaign),
        // «Дальше» ведёт на тропу с листом узла, а не сразу в партию: колоду и условия можно посмотреть.
        onNext: (next) => context.go(AppRoutes.campaignOpen(next)),
        onChangeDeck: (node) => context.go(AppRoutes.campaignDecksFor(node)),
        onBuildDeck: () => unawaited(_buildDeckThenChoose(context, nodeId)),
        onSettings: () => context.push(AppRoutes.settingsOverGame),
        onHowToPlay: () => context.push(AppRoutes.howToPlay(overGame: true)),
        confirmPass: settings.confirmPass,
        hints: settings.hints,
        animationScale: switch (settings.animationSpeed) {
          AnimationSpeed.normal => 1,
          AnimationSpeed.fast => StageTokens.fastFactor,
        },
        sound: dependencies.playSound,
        haptic: dependencies.playHaptic,
      );
    },
  ),
);

/// Собрать колоду из партии узла [nodeId] и вернуться к выбору колоды для этого же узла.
Future<void> _buildDeckThenChoose(BuildContext context, String nodeId) async {
  await context.push<void>(AppRoutes.campaignDeckNew);
  if (context.mounted) context.go(AppRoutes.campaignDecksFor(nodeId));
}

/// Конструктор колоды в режиме лобби: колоду [deckId] или новую. Закрывается, вернув идентификатор сохранённой колоды
/// (или `null`, если игрок вышел, ничего не сохранив).
Widget _lobbyBuilder(BuildContext context, AppDependencies dependencies, {String? deckId}) => BlocProvider(
  create: (_) => DeckEditorCubit(
    loadDeckRules: dependencies.loadDeckRules,
    getDeck: dependencies.getDeck,
    saveDeck: dependencies.saveDeck,
    newDeckName: context.l10n.deckListNew,
    deckId: deckId,
    sound: dependencies.playSound,
  ),
  child: LobbyBuilderScreen(
    onSaved: (savedId) => context.pop(savedId),
    onCancel: () => context.pop(),
  ),
);

/// Экран сетевой партии: стол уже начат в комнате, держатель берёт его у сетевой игры.
Widget _networkMatch(BuildContext context, AppDependencies dependencies) {
  final settings = dependencies.watchSettings();
  final game = dependencies.activeNetworkGame.current;
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) {
          final bloc = MatchBloc(dependencies.startMatch, dependencies.recordFinishedMatch, awaitingSession: true);
          if (game != null) bloc.add(MatchSessionOpened(game.openMatch()));
          return bloc;
        },
      ),
      BlocProvider(
        create: (_) => FieldCubit(sound: dependencies.playSound, haptic: dependencies.playHaptic),
      ),
      if (game != null) BlocProvider(create: (_) => MatchConnectionCubit(game)),
    ],
    child: StreamBuilder<AppSettings>(
      stream: settings,
      initialData: const AppSettings(),
      builder: (context, snapshot) => MatchScreen(
        onExit: () => context.go(AppRoutes.menu),
        // Оба согласились на реванш: колоды выбирают заново в той же комнате.
        onRematchAgreed: () => context.go(AppRoutes.playRoom),
        onEditDeck: (_) {},
        onSettings: () => context.push(AppRoutes.settingsOverGame),
        onHowToPlay: () => context.push(AppRoutes.howToPlay(overGame: true)),
        confirmPass: (snapshot.data ?? const AppSettings()).confirmPass,
        hints: (snapshot.data ?? const AppSettings()).hints,
        animationScale: switch ((snapshot.data ?? const AppSettings()).animationSpeed) {
          AnimationSpeed.normal => 1,
          AnimationSpeed.fast => StageTokens.fastFactor,
        },
        opponentStatus: game == null ? null : const MatchConnectionIndicator(),
        overlay: game == null
            ? null
            : Builder(
                builder: (context) => MatchConnectionLayer(
                  // Хост, не дождавшись гостя, засчитывает себе поражение; гость просто уходит, а хост по истечении
                  // времени сдаст его место сам.
                  onEnd: game.isHost
                      ? () => context.read<MatchBloc>().add(const MatchIntentSubmitted(Resign()))
                      : () => context.go(AppRoutes.menu),
                ),
              ),
      ),
    ),
  );
}

/// Режим партии из параметра пути; без параметра — против бота.
LocalMatchMode _matchMode(GoRouterState state) =>
    state.uri.queryParameters[AppRoutes.matchModeParam] == 'hotSeat' ? LocalMatchMode.hotSeat : LocalMatchMode.vsBot;

/// Путь вложенного маршрута относительно меню: `/decks` → `decks`.
String _child(String path) => path.substring(AppRoutes.menu.length);
