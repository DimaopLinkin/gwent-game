import 'package:flutter/material.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Тема приложения по дизайн-системе (макет Claude Design, промпт 0).
///
/// Material-виджеты получают токены отсюда: основная кнопка — [FilledButton], второстепенная — [OutlinedButton],
/// кнопка-иконка — [IconButton], тост — [SnackBar]. Градиенты кожи и латуни Material не умеет, поэтому кнопки
/// залиты средним цветом градиента из макета. Игровые компоненты (карта, ряд, «Пас») рисуются своими виджетами
/// прямо по токенам из `core/presentation/design_system`.
abstract final class AppTheme {
  /// Тёмная тема стола.
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: GwentColors.gold,
      onPrimary: GwentColors.onGold,
      secondary: GwentColors.brass,
      onSecondary: GwentColors.textPrimary,
      tertiary: GwentColors.parchment,
      onTertiary: GwentColors.onParchment,
      error: GwentColors.errorText,
      onError: GwentColors.bg,
      surface: GwentColors.bg,
      onSurface: GwentColors.textPrimary,
      onSurfaceVariant: GwentColors.textSecondary,
      surfaceContainerLowest: GwentColors.bg,
      surfaceContainerLow: GwentColors.panel,
      surfaceContainer: GwentColors.surface,
      surfaceContainerHigh: GwentColors.surfaceRaised,
      surfaceContainerHighest: GwentColors.surfaceRaised,
      outline: GwentColors.brass,
      outlineVariant: GwentColors.line,
      scrim: GwentColors.scrim,
      shadow: Colors.black,
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(GwentSpace.radiusM));
    const buttonSize = Size(GwentSpace.buttonHeight, GwentSpace.buttonHeight);
    const buttonPadding = EdgeInsets.symmetric(horizontal: GwentSpace.buttonPadding);

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GwentColors.bg,
      canvasColor: GwentColors.bg,
      dividerColor: GwentColors.line,
      focusColor: GwentColors.focusRing.withValues(alpha: 0.12),
      splashFactory: NoSplash.splashFactory,
      fontFamily: GwentText.alegreya,
      textTheme: _textTheme,
      iconTheme: const IconThemeData(color: GwentColors.gold, size: 24),
      appBarTheme: const AppBarTheme(
        backgroundColor: GwentColors.bg,
        foregroundColor: GwentColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GwentText.title,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          padding: const WidgetStatePropertyAll(buttonPadding),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: const WidgetStatePropertyAll(GwentText.label),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? GwentColors.disabledFill
                : states.contains(WidgetState.pressed)
                ? GwentColors.brassLight
                : GwentColors.gold,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? GwentColors.disabledText : GwentColors.onGold,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled) ? GwentColors.line : GwentColors.brassDark,
            ),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          padding: const WidgetStatePropertyAll(buttonPadding),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: const WidgetStatePropertyAll(GwentText.label),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? GwentColors.panel
                : states.contains(WidgetState.pressed)
                ? GwentColors.pressed
                : GwentColors.surfaceRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? GwentColors.muted
                : states.contains(WidgetState.pressed)
                ? GwentColors.gold
                : GwentColors.textPrimary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? GwentColors.panelLine
                  : states.contains(WidgetState.pressed)
                  ? GwentColors.gold
                  : GwentColors.brass,
            ),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(GwentSpace.minTapTarget)),
          iconSize: const WidgetStatePropertyAll(24),
          shape: const WidgetStatePropertyAll(CircleBorder()),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? GwentColors.pressed : GwentColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? GwentColors.muted
                : states.contains(WidgetState.pressed)
                ? GwentColors.textPrimary
                : GwentColors.gold,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? GwentColors.panelLine
                  : states.contains(WidgetState.pressed)
                  ? GwentColors.gold
                  : GwentColors.brass,
            ),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? GwentColors.line
              : states.contains(WidgetState.selected)
              ? GwentColors.gold
              : GwentColors.brass,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? GwentColors.panel
              : states.contains(WidgetState.selected)
              ? GwentColors.switchTrackOn
              : GwentColors.bg,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? GwentColors.panelLine
              : states.contains(WidgetState.selected)
              ? GwentColors.gold
              : GwentColors.line,
        ),
        // Пустая иконка без глифа: в Material 3 она увеличивает выключенную ручку с 16 до 24 pt, как в макете.
        thumbIcon: const WidgetStatePropertyAll(Icon(null)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GwentColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        barrierColor: GwentColors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GwentSpace.radiusM),
          side: const BorderSide(color: GwentColors.brass),
        ),
        titleTextStyle: GwentText.title.copyWith(fontSize: 26, height: 1.1),
        contentTextStyle: GwentText.body.copyWith(fontSize: 15, height: 21 / 15, color: GwentColors.textSecondary),
        actionsPadding: const EdgeInsets.fromLTRB(
          GwentSpace.space6,
          GwentSpace.space2,
          GwentSpace.space6,
          GwentSpace.space6,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GwentColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: GwentColors.scrim,
        showDragHandle: true,
        dragHandleColor: GwentColors.brass,
        dragHandleSize: Size(40, 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(GwentSpace.radiusL)),
          side: BorderSide(color: GwentColors.brass),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: GwentColors.parchment,
        contentTextStyle: GwentText.body.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          height: 1.3,
          color: GwentColors.onParchment,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GwentSpace.radiusS),
          side: const BorderSide(color: GwentColors.brass),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: GwentColors.gold,
        unselectedLabelColor: GwentColors.textSecondary,
        indicatorColor: GwentColors.gold,
        dividerColor: GwentColors.line,
        labelStyle: GwentText.label.copyWith(fontSize: 16, height: 1, letterSpacing: 16 * 0.04),
        unselectedLabelStyle: GwentText.label.copyWith(fontSize: 16, height: 1, letterSpacing: 16 * 0.04),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GwentColors.gold,
        circularTrackColor: GwentColors.line,
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displaySmall: GwentText.display,
    headlineSmall: GwentText.title,
    titleLarge: GwentText.title,
    titleMedium: GwentText.label,
    labelLarge: GwentText.label,
    bodyLarge: GwentText.body,
    bodyMedium: GwentText.body,
    bodySmall: GwentText.caption,
    labelSmall: GwentText.caption,
  );
}
