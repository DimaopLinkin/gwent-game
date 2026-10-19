import 'dart:async';

import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/app/router/app_routes.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_screen.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_screen.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_screen.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_screen.dart';
import 'package:gwent/src/features/lobby/presentation/host_invite_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/host_qr_screen.dart';
import 'package:gwent/src/features/lobby/presentation/lobby_builder_screen.dart';
import 'package:gwent/src/features/lobby/presentation/lobby_deck_picker_screen.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_layer.dart';
import 'package:gwent/src/features/lobby/presentation/play_method_screen.dart';
import 'package:gwent/src/features/lobby/presentation/qr_scan_screen.dart';
import 'package:gwent/src/features/lobby/presentation/room_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_screen.dart';
import 'package:gwent/src/features/match/domain/match_session.dart' show LocalMatchMode;
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent/src/features/menu/presentation/menu_screen.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/presentation/settings_cubit.dart';
import 'package:gwent/src/features/settings/presentation/settings_screen.dart';
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
        onSettings: () => context.go(AppRoutes.settings),
      ),
      routes: [
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
            onCreate: () => context.go(AppRoutes.playCreate),
            onFind: () => context.go(AppRoutes.playFind),
            onBack: () => context.go(AppRoutes.menu),
          ),
          routes: [
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
                return BlocProvider(
                  create: (_) => RoomCubit(game, dependencies.loadDeckRules, dependencies.getDeck),
                  child: RoomScreen(
                    isHost: game.isHost,
                    title: game.title ?? '',
                    onPickDeck: (deckId) => context.push<String>(AppRoutes.playRoomDecks, extra: deckId),
                    onBuildDeck: (deckId) => context.push<String>(
                      deckId == null ? AppRoutes.playRoomBuild : AppRoutes.playRoomBuildDeck(deckId),
                    ),
                    onShowQr: () => context.push(AppRoutes.playRoomQr),
                    onStarted: () => context.go(AppRoutes.playMatch),
                    onLeft: () => context.go(AppRoutes.play),
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
          builder: (context, state) => BlocProvider(
            create: (_) => SettingsCubit(
              watchSettings: dependencies.watchSettings,
              saveSettings: dependencies.saveSettings,
              loadAboutInfo: dependencies.loadAboutInfo,
              checkContentUpdate: dependencies.checkContentUpdate,
            ),
            child: SettingsScreen(
              // Из партии настройки открывают поверх неё (push), оттуда возвращаются назад, а не в меню.
              onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.menu),
              onLicenses: () => showLicensePage(context: context, applicationName: context.l10n.appTitle),
            ),
          ),
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
                BlocProvider(create: (_) => FieldCubit()),
              ],
              child: StreamBuilder<AppSettings>(
                stream: settings,
                initialData: const AppSettings(),
                builder: (context, snapshot) => MatchScreen(
                  onExit: () => context.go(AppRoutes.menu),
                  // Конструктор открывается поверх выбора, а не вместо него: после правки игрок возвращается к тому же шагу.
                  onEditDeck: (deckId) => context.push(AppRoutes.deckEdit(deckId)),
                  onSettings: () => context.push(AppRoutes.settings),
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
  ),
  child: DeckEditorScreen(onExit: () => context.pop()),
);

/// Конструктор колоды в режиме лобби: колоду [deckId] или новую. Закрывается, вернув идентификатор сохранённой колоды
/// (или `null`, если игрок вышел, ничего не сохранив).
Widget _lobbyBuilder(BuildContext context, AppDependencies dependencies, {String? deckId}) => BlocProvider(
  create: (_) => DeckEditorCubit(
    loadDeckRules: dependencies.loadDeckRules,
    getDeck: dependencies.getDeck,
    saveDeck: dependencies.saveDeck,
    newDeckName: context.l10n.deckListNew,
    deckId: deckId,
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
      BlocProvider(create: (_) => FieldCubit()),
      if (game != null) BlocProvider(create: (_) => MatchConnectionCubit(game)),
    ],
    child: StreamBuilder<AppSettings>(
      stream: settings,
      initialData: const AppSettings(),
      builder: (context, snapshot) => MatchScreen(
        onExit: () => context.go(AppRoutes.menu),
        onEditDeck: (_) {},
        onSettings: () => context.push(AppRoutes.settings),
        animationScale: switch ((snapshot.data ?? const AppSettings()).animationSpeed) {
          AnimationSpeed.normal => 1,
          AnimationSpeed.fast => StageTokens.fastFactor,
        },
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
