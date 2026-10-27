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
    required this.onHistory,
    required this.onTutorial,
    required this.onSettings,
    this.onCampaign,
  });

  /// Партия на одном телефоне.
  final VoidCallback onHotSeat;

  /// Партия против бота.
  final VoidCallback onBot;

  /// Сетевая игра.
  final VoidCallback onNetworkGame;

  /// Конструктор колоды.
  final VoidCallback onDecks;

  /// История партий.
  final VoidCallback onHistory;

  /// Обучение: «Первая партия».
  final VoidCallback onTutorial;

  /// Настройки.
  final VoidCallback onSettings;

  /// Кампания «Тропа ведьмака»; `null` — кнопки нет.
  final VoidCallback? onCampaign;

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
              onHistory: widget.onHistory,
              onTutorial: widget.onTutorial,
              onSettings: widget.onSettings,
              onCampaign: widget.onCampaign,
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
    required this.onHistory,
    required this.onTutorial,
    required this.onSettings,
    required this.onCampaign,
  });

  final MenuState state;
  final VoidCallback onHotSeat;
  final VoidCallback onBot;
  final VoidCallback onNetworkGame;
  final VoidCallback onDecks;
  final VoidCallback onHistory;
  final VoidCallback onTutorial;
  final VoidCallback onSettings;
  final VoidCallback? onCampaign;

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
                      if (ready?.campaign case final campaign? when onCampaign != null)
                        _CampaignButton(
                          title: l10n.menuCampaign,
                          subtitle: campaign.started
                              ? l10n.menuCampaignProgress(
                                  campaign.chapterNumber,
                                  campaign.chapterName,
                                  campaign.passed,
                                  campaign.total,
                                )
                              : l10n.menuCampaignNew,
                          isNew: !campaign.started,
                          newLabel: l10n.menuTutorialNew,
                          onPressed: ready!.contentAvailable ? onCampaign : null,
                        ),
                      _Button(label: l10n.menuHotSeat, fontSize: 21, onPressed: canPlay ? onHotSeat : null),
                      _Button(label: l10n.menuVsBot, onPressed: canPlay ? onBot : null),
                      _Button(label: l10n.menuNetworkGame, onPressed: canPlay ? onNetworkGame : null),
                      _Button(
                        label: l10n.menuDecks,
                        gold: highlightDecks,
                        labelColor: highlightDecks ? GwentColors.goldHighlight : null,
                        onPressed: onDecks,
                      ),
                      Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: _SmallButton(label: l10n.menuHistoryShort, onPressed: onHistory),
                          ),
                          Expanded(
                            child: _SmallButton(
                              label: l10n.menuTutorial,
                              onPressed: onTutorial,
                              mark: switch (ready) {
                                null => null,
                                MenuReady(firstMatchPassed: true) => _Mark.done(l10n.menuTutorialDone),
                                MenuReady() => _Mark.fresh(l10n.menuTutorialNew),
                              },
                            ),
                          ),
                          Expanded(
                            child: _SmallButton(label: l10n.menuSettings, onPressed: onSettings),
                          ),
                        ],
                      ),
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

  /// Золотая кнопка; `null` — золотая, пока она доступна и это кнопка игры (все, кроме «Колод», «Истории партий» и «Настроек»).
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

/// Главная кнопка «Кампания»: подпись показывает место на тропе, у нового игрока стоит метка «Новое».
class _CampaignButton extends StatelessWidget {
  const _CampaignButton({
    required this.title,
    required this.subtitle,
    required this.isNew,
    required this.newLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final bool isNew;
  final String newLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      SizedBox(
        width: double.infinity,
        child: GwentButton(
          label: title,
          fontSize: 24,
          height: 66,
          solid: true,
          semanticsLabel: '$title. $subtitle',
          onPressed: onPressed,
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 7,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1,
                color: GwentColors.onGold,
              ),
            ),
          ),
        ),
      ),
      if (isNew)
        Positioned(
          top: -7,
          right: 12,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GwentColors.lifeGem,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [BoxShadow(color: GwentColors.bg, spreadRadius: 1.5)],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    newLabel,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      height: 1,
                      letterSpacing: 11 * 0.05,
                      color: GwentColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Метка в углу малой кнопки: «Новое» у непройденного обучения, галочка у пройденного.
class _Mark {
  const _Mark.fresh(this.label) : fresh = true;
  const _Mark.done(this.label) : fresh = false;

  final String label;
  final bool fresh;
}

/// Малая кнопка ряда «История / Обучение / Настройки»: подпись сжимается, а не обрезается, на узких экранах.
class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onPressed, this.mark});

  final String label;
  final VoidCallback onPressed;
  final _Mark? mark;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      SizedBox(
        width: double.infinity,
        child: GwentButton(
          label: label,
          fontSize: 16,
          height: 48,
          shrinkToFit: true,
          solid: true,
          style: GwentButtonStyle.secondary,
          onPressed: onPressed,
        ),
      ),
      if (mark case final mark?)
        Positioned(
          top: -7,
          right: 8,
          child: IgnorePointer(
            child: Semantics(
              label: mark.label,
              child: ExcludeSemantics(
                child: mark.fresh
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: GwentColors.gold,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [BoxShadow(color: GwentColors.bg, spreadRadius: 1.5)],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          child: Text(
                            mark.label,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: GwentText.cormorant,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              height: 1,
                              letterSpacing: 11 * 0.05,
                              color: GwentColors.onGold,
                            ),
                          ),
                        ),
                      )
                    : const Text(
                        '✓',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(fontSize: 14, height: 1, color: GwentColors.gold),
                      ),
              ),
            ),
          ),
        ),
    ],
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
