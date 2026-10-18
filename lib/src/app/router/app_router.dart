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
import 'package:gwent/src/features/lobby/presentation/lobby_screen.dart';
import 'package:gwent/src/features/match/domain/match_session.dart' show LocalMatchMode;
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent/src/features/menu/presentation/menu_screen.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/presentation/settings_cubit.dart';
import 'package:gwent/src/features/settings/presentation/settings_screen.dart';

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
        onNetworkGame: () => context.go(AppRoutes.lobby),
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
        GoRoute(path: _child(AppRoutes.lobby), builder: (context, state) => const LobbyScreen()),
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
              onBack: () => context.go(AppRoutes.menu),
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

/// Режим партии из параметра пути; без параметра — против бота.
LocalMatchMode _matchMode(GoRouterState state) =>
    state.uri.queryParameters[AppRoutes.matchModeParam] == 'hotSeat' ? LocalMatchMode.hotSeat : LocalMatchMode.vsBot;

/// Путь вложенного маршрута относительно меню: `/decks` → `decks`.
String _child(String path) => path.substring(AppRoutes.menu.length);
