import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/app/router/app_routes.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_builder_screen.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/lobby_screen.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/menu/presentation/menu_screen.dart';

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
        onHotSeat: () => context.go(AppRoutes.match),
        onNetworkGame: () => context.go(AppRoutes.lobby),
        onDecks: () => context.go(AppRoutes.decks),
      ),
      routes: [
        GoRoute(
          path: _child(AppRoutes.decks),
          builder: (context, state) => BlocProvider(
            create: (_) => DeckListCubit(dependencies.watchDecks),
            child: const DeckBuilderScreen(),
          ),
        ),
        GoRoute(path: _child(AppRoutes.lobby), builder: (context, state) => const LobbyScreen()),
        GoRoute(path: _child(AppRoutes.match), builder: (context, state) => const MatchScreen()),
      ],
    ),
  ],
);

/// Путь вложенного маршрута относительно меню: `/decks` → `decks`.
String _child(String path) => path.substring(AppRoutes.menu.length);
