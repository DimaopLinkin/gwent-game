import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/menu/presentation/menu_backdrop.dart';
import 'package:gwent/src/features/menu/presentation/menu_cubit.dart';
import 'package:gwent/src/features/menu/presentation/menu_state.dart';
import 'package:gwent/src/features/menu/presentation/splash_layer.dart';

/// Главное меню (макет 6): заставка при запуске, затем стол с названием и пятью кнопками.
///
/// Переходы приходят снаружи, поэтому экран не знает о навигации и других фичах. Пока играть нельзя (нет колоды
/// или набор карт не загружен), кнопки игры погашены, над ними подсказка, а «Колоды» подсвечена. Заставку показывает
/// только первое меню после запуска: держатель `MenuCubit` живёт всё время работы приложения.
class MenuScreen extends StatefulWidget {
  /// Создаёт меню.
  const MenuScreen({
    super.key,
    required this.onHotSeat,
    required this.onBot,
    required this.onNetworkGame,
    required this.onDecks,
    required this.onSettings,
  });

  /// Партия на одном телефоне.
  final VoidCallback onHotSeat;

  /// Партия против бота.
  final VoidCallback onBot;

  /// Сетевая игра.
  final VoidCallback onNetworkGame;

  /// Конструктор колоды.
  final VoidCallback onDecks;

  /// Настройки.
  final VoidCallback onSettings;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late bool _splash = context.read<MenuCubit>().state is MenuLoading;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GwentColors.bg,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const MenuBackdrop(),
        SafeArea(
          child: BlocBuilder<MenuCubit, MenuState>(
            builder: (context, state) => _Menu(
              state: state,
              onHotSeat: widget.onHotSeat,
              onBot: widget.onBot,
              onNetworkGame: widget.onNetworkGame,
              onDecks: widget.onDecks,
              onSettings: widget.onSettings,
            ),
          ),
        ),
        if (_splash)
          BlocBuilder<MenuCubit, MenuState>(
            builder: (context, state) => SplashLayer(
              ready: state is MenuReady,
              onDone: () => setState(() => _splash = false),
            ),
          ),
      ],
    ),
  );
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.state,
    required this.onHotSeat,
    required this.onBot,
    required this.onNetworkGame,
    required this.onDecks,
    required this.onSettings,
  });

  final MenuState state;
  final VoidCallback onHotSeat;
  final VoidCallback onBot;
  final VoidCallback onNetworkGame;
  final VoidCallback onDecks;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = switch (state) {
      final MenuReady ready => ready,
      MenuLoading() => null,
    };
    // Пока меню грузится, оно уже нарисовано под заставкой, но кнопки игры не нажать.
    final canPlay = ready?.canPlay ?? false;
    final hint = ready == null || canPlay
        ? null
        : ready.contentAvailable
        ? l10n.menuNoDeckHint
        : l10n.menuContentFailed;
    final highlightDecks = ready != null && !canPlay;
    final version = switch (ready) {
      MenuReady(:final appVersion?, :final packVersion?) => l10n.menuVersion(appVersion, packVersion),
      MenuReady(:final appVersion?) => l10n.menuVersionApp(appVersion),
      _ => null,
    };
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Column(
                children: [
                  const SizedBox(height: 226),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
                    ),
                    child: Column(
                      spacing: 6,
                      children: [
                        const _TitleOrnament(),
                        GwentLogo(text: l10n.appTitle.toUpperCase(), size: 76, spacing: 0.14),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Hint(text: hint, action: l10n.menuToBuilder, onAction: onDecks),
                    ),
                  Column(
                    spacing: 10,
                    children: [
                      _Button(label: l10n.menuHotSeat, fontSize: 21, onPressed: canPlay ? onHotSeat : null),
                      _Button(label: l10n.menuVsBot, onPressed: canPlay ? onBot : null),
                      _Button(label: l10n.menuNetworkGame, onPressed: canPlay ? onNetworkGame : null),
                      _Button(
                        label: l10n.menuDecks,
                        gold: highlightDecks,
                        labelColor: highlightDecks ? GwentColors.goldHighlight : null,
                        onPressed: onDecks,
                      ),
                      _Button(label: l10n.menuSettings, gold: false, onPressed: onSettings),
                    ],
                  ),
                  if (version != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        version,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.alegreya,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          height: 1,
                          letterSpacing: 12 * 0.04,
                          color: Color(0xFF8A7D64),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка меню: золотая для игры (и подсвеченных «Колод»), латунная для остальных, погашенная без обработчика.
class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onPressed, this.fontSize = 22, this.gold, this.labelColor});

  final String label;
  final VoidCallback? onPressed;
  final double fontSize;

  /// Золотая кнопка; `null` — золотая, пока она доступна и это кнопка игры (все, кроме «Колод» и «Настроек»).
  final bool? gold;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: GwentButton(
      label: label,
      fontSize: fontSize,
      solid: true,
      labelColor: labelColor,
      style: (gold ?? true) ? GwentButtonStyle.primary : GwentButtonStyle.secondary,
      onPressed: onPressed,
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.action, required this.onAction});

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
    decoration: BoxDecoration(
      color: const Color(0xEB14110E),
      borderRadius: BorderRadius.circular(6),
      boxShadow: const [BoxShadow(color: GwentColors.brass, spreadRadius: 1)],
    ),
    child: Row(
      spacing: 12,
      children: [
        Expanded(
          child: Text(
            text,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: GwentText.alegreya,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              fontSize: 16,
              height: 1.25,
              color: GwentColors.goldHighlight,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: action,
          excludeSemantics: true,
          onTap: onAction,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [GwentColors.goldHighlight, GwentColors.brassLight],
                ),
                boxShadow: const [BoxShadow(color: GwentColors.bg, spreadRadius: 1)],
              ),
              child: Text(
                action,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1,
                  letterSpacing: 16 * 0.05,
                  color: GwentColors.onGold,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TitleOrnament extends StatelessWidget {
  const _TitleOrnament();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 14,
    children: [
      const SizedBox(
        width: 60,
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x008C6A3F), GwentColors.brass])),
        ),
      ),
      Transform.rotate(
        angle: 0.7853981633974483,
        child: const SizedBox.square(dimension: 7, child: ColoredBox(color: GwentColors.gold)),
      ),
      const SizedBox(
        width: 60,
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [GwentColors.brass, Color(0x008C6A3F)])),
        ),
      ),
    ],
  );
}
