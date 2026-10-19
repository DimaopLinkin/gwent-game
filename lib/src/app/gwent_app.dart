import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/app/router/app_router.dart';
import 'package:gwent/src/app/theme/app_theme.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/menu/presentation/menu_cubit.dart';

/// Корневой виджет: тема, локализация и навигация.
class GwentApp extends StatefulWidget {
  /// Создаёт приложение над собранными [dependencies].
  const GwentApp({super.key, required this.dependencies});

  /// Сценарии из точки сборки.
  final AppDependencies dependencies;

  @override
  State<GwentApp> createState() => _GwentAppState();
}

class _GwentAppState extends State<GwentApp> {
  late final GoRouter _router = createAppRouter(widget.dependencies);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    // Меню живёт всё время работы приложения: заставка идёт один раз, а не при каждом возврате в меню.
    create: (_) => MenuCubit(widget.dependencies.loadMenu, widget.dependencies.watchDecks),
    child: MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    ),
  );
}
