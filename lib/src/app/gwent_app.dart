import 'dart:async';

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

  // Хост сообщает, что свернул приложение, пока оно ещё отвечает: гость видит «партия на паузе», а не обрыв. Если ОС
  // заморозит процесс хоста надолго, обрыв засчитывается как обычно (ADR 0020).
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final dependencies = widget.dependencies;
    _lifecycle = AppLifecycleListener(
      onHide: () {
        dependencies.activeNetworkGame.current?.setAway(away: true);
        dependencies.playSound.suspend();
        unawaited(dependencies.backgroundMusic.pause());
      },
      onShow: () {
        dependencies.activeNetworkGame.current?.setAway(away: false);
        dependencies.playSound.resume();
        unawaited(dependencies.backgroundMusic.resume());
      },
    );
    // Звук и музыка готовятся и запускаются в фоне: меню не ждёт их, а сбой звука игру не останавливает. Эффекты
    // готовятся, когда музыка уже запущена: пока грузится композиция, лишних проигрывателей не создаётся.
    unawaited(dependencies.backgroundMusic.start().whenComplete(dependencies.playSound.preload));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    // Меню живёт всё время работы приложения: заставка идёт один раз, а не при каждом возврате в меню.
    create: (_) => MenuCubit(
      widget.dependencies.loadMenu,
      widget.dependencies.watchDecks,
      sound: widget.dependencies.playSound,
    ),
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
