import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/gwent_slider.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/settings/domain/about_info.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/presentation/settings_cubit.dart';
import 'package:gwent/src/features/settings/presentation/settings_state.dart';
import 'package:gwent/src/features/settings/presentation/settings_widgets.dart';
import 'package:intl/intl.dart';

/// Экран настроек (макет 10): пять групп на тёмной поверхности — игра, звук, язык, данные карт и сведения о приложении.
///
/// Изменения сохраняются сразу, кнопки «Сохранить» нет. Настройки, чьи функции ещё не подключены к игре (имя в сети,
/// скорость анимаций, подсказки, громкость, подтверждение паса), сохраняются и показываются как есть. Переходы приходят
/// снаружи: экран не знает о маршрутах.
class SettingsScreen extends StatelessWidget {
  /// Создаёт экран; [onBack] выходит из настроек, [onLicenses] открывает лицензии шрифтов и библиотек.
  const SettingsScreen({super.key, required this.onBack, required this.onLicenses});

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// Игрок открыл лицензии.
  final VoidCallback onLicenses;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: GwentColors.bg,
      body: ScreenBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                spacing: 8,
                children: [
                  ChevronButton(label: l10n.settingsBack, onPressed: onBack),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.settingsTitle,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                          height: 1,
                          letterSpacing: 30 * 0.06,
                          color: GwentColors.goldHighlight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, state) => switch (state) {
                  SettingsLoading() => const GameLoader(),
                  SettingsFailed() => Center(
                    child: Text(
                      l10n.settingsLoadFailed,
                      textAlign: TextAlign.center,
                      style: GwentText.body.copyWith(fontSize: 17, color: GwentColors.textSecondary),
                    ),
                  ),
                  final SettingsLoaded loaded => _Settings(state: loaded, onLicenses: onLicenses),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings({required this.state, required this.onLicenses});

  final SettingsLoaded state;
  final VoidCallback onLicenses;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SettingsCubit>();
    final settings = state.settings;
    final about = state.about;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
      children: [
        SettingsGroup(
          title: l10n.settingsGroupGame,
          children: [
            _PlayerNameField(initialName: settings.playerName, onChanged: cubit.setPlayerName),
            SettingsSwitchRow(
              label: l10n.settingsConfirmPass,
              value: settings.confirmPass,
              onChanged: (value) => cubit.setConfirmPass(value: value),
            ),
            SettingsChoiceRow(
              label: l10n.settingsAnimationSpeed,
              options: [
                SettingsChoice(
                  label: l10n.settingsSpeedNormal,
                  selected: settings.animationSpeed == AnimationSpeed.normal,
                  onSelected: () => cubit.setAnimationSpeed(AnimationSpeed.normal),
                ),
                SettingsChoice(
                  label: l10n.settingsSpeedFast,
                  selected: settings.animationSpeed == AnimationSpeed.fast,
                  onSelected: () => cubit.setAnimationSpeed(AnimationSpeed.fast),
                ),
              ],
            ),
            SettingsSwitchRow(
              label: l10n.settingsHints,
              value: settings.hints,
              onChanged: (value) => cubit.setHints(value: value),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          title: l10n.settingsGroupSound,
          children: [
            SettingsSliderRow(
              label: l10n.settingsMusic,
              valueText: l10n.settingsVolumeValue(settings.musicVolume),
              slider: GwentSlider(
                value: settings.musicVolume,
                semanticLabel: l10n.settingsMusic,
                semanticValue: l10n.settingsVolumeValue(settings.musicVolume),
                onChanged: cubit.changeMusicVolume,
                onChangeEnd: cubit.saveVolumes,
              ),
            ),
            SettingsSliderRow(
              label: l10n.settingsEffects,
              valueText: l10n.settingsVolumeValue(settings.effectsVolume),
              slider: GwentSlider(
                value: settings.effectsVolume,
                semanticLabel: l10n.settingsEffects,
                semanticValue: l10n.settingsVolumeValue(settings.effectsVolume),
                onChanged: cubit.changeEffectsVolume,
                onChangeEnd: cubit.saveVolumes,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          title: l10n.settingsGroupLanguage,
          children: [
            SettingsLanguageRow.selected(label: l10n.settingsLanguageRussian),
            SettingsLanguageRow.soon(label: l10n.settingsLanguageEnglish, soonLabel: l10n.settingsSoon),
            SettingsLanguageRow.soon(label: l10n.settingsLanguagePolish, soonLabel: l10n.settingsSoon),
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          title: l10n.settingsGroupContent,
          children: [
            SettingsChoiceRow(
              label: l10n.settingsContentSource,
              options: [
                SettingsChoice(
                  label: l10n.settingsSourceBuiltIn,
                  semanticsLabel: l10n.settingsSourceBuiltInFull,
                  selected: true,
                  onSelected: () {},
                ),
                SettingsChoice(label: l10n.settingsSourceServer, selected: false, onSelected: null),
              ],
            ),
            SettingsValueRow(
              label: l10n.settingsPackVersion,
              value: about.packVersion?.toString() ?? l10n.settingsValueUnknown,
            ),
            SettingsValueRow(
              label: l10n.settingsUpdatedAt,
              value: _date(context, settings.contentCheckedAt) ?? l10n.settingsValueUnknown,
            ),
            _CheckUpdate(status: state.update, onCheck: cubit.checkContentUpdate),
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          title: l10n.settingsGroupAbout,
          footer: l10n.settingsFanProject,
          children: [
            SettingsValueRow(label: l10n.settingsAppVersion, value: _appVersion(context, about)),
            SettingsValueRow(label: l10n.settingsProtocol, value: l10n.settingsProtocolValue(about.protocolVersion)),
            SettingsLinkRow(label: l10n.settingsLicenses, onTap: onLicenses),
          ],
        ),
      ],
    );
  }

  /// Дата проверки по местному времени игрока; `null`, если проверки ещё не было.
  String? _date(BuildContext context, DateTime? checkedAt) =>
      checkedAt == null ? null : DateFormat.yMd(Localizations.localeOf(context).toString()).format(checkedAt.toLocal());

  String _appVersion(BuildContext context, AboutInfo about) {
    final l10n = context.l10n;
    final version = about.appVersion;
    final build = about.buildNumber;
    if (version == null) return l10n.settingsValueUnknown;
    return build == null || build.isEmpty ? version : l10n.settingsAppVersionBuild(version, build);
  }
}

/// Поле имени игрока (макет 10): подпись, ввод 44 pt и пояснение. Имя сохраняется при каждом изменении, поэтому
/// выход с экрана ничего не теряет.
class _PlayerNameField extends StatefulWidget {
  const _PlayerNameField({required this.initialName, required this.onChanged});

  final String? initialName;
  final ValueChanged<String> onChanged;

  @override
  State<_PlayerNameField> createState() => _PlayerNameFieldState();
}

class _PlayerNameFieldState extends State<_PlayerNameField> {
  static const int _maxLength = 20;

  late final TextEditingController _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const textStyle = TextStyle(
      fontFamily: GwentText.alegreya,
      fontWeight: FontWeight.w500,
      fontSize: 17,
      height: 1,
      color: GwentColors.textPrimary,
    );
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: color, width: width),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(l10n.settingsPlayerName, style: textStyle.copyWith(height: 1.2)),
          Semantics(
            label: l10n.settingsPlayerName,
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                inputFormatters: [LengthLimitingTextInputFormatter(_maxLength)],
                textInputAction: TextInputAction.done,
                style: textStyle,
                cursorColor: GwentColors.gold,
                decoration: InputDecoration(
                  hintText: l10n.settingsPlayerNameHint,
                  hintStyle: textStyle.copyWith(color: GwentColors.muted),
                  filled: true,
                  fillColor: const Color(0xFF0B0907),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  enabledBorder: border(GwentColors.muted),
                  focusedBorder: border(GwentColors.gold, 1.5),
                ),
              ),
            ),
          ),
          Text(
            l10n.settingsPlayerNameNote,
            style: const TextStyle(
              fontFamily: GwentText.alegreya,
              fontSize: 13,
              height: 1.3,
              color: Color(0xFF8A7D64),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка «Проверить обновление» и строка состояния под ней: проверка, «актуален» или ошибка.
class _CheckUpdate extends StatelessWidget {
  const _CheckUpdate({required this.status, required this.onCheck});

  final ContentUpdateStatus status;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final checking = status == ContentUpdateStatus.checking;
    return Padding(
      padding: const EdgeInsets.all(12).copyWith(left: 16, right: 16),
      child: Column(
        spacing: 10,
        children: [
          GwentButton(
            label: l10n.settingsCheckUpdate,
            fontSize: 21,
            onPressed: checking ? null : onCheck,
          ),
          switch (status) {
            ContentUpdateStatus.idle => const SizedBox.shrink(),
            ContentUpdateStatus.checking => _StatusLine(
              leading: const GwentSpinner(size: 16),
              text: l10n.settingsChecking,
              style: const TextStyle(fontStyle: FontStyle.italic, color: GwentColors.goldHighlight),
            ),
            ContentUpdateStatus.upToDate => _StatusLine(
              leading: const DiamondMarker(size: 8, color: GwentColors.goldHighlight),
              text: l10n.settingsUpToDate,
              style: const TextStyle(color: GwentColors.goldHighlight),
            ),
            ContentUpdateStatus.failed => _StatusLine(
              text: l10n.settingsCheckFailed,
              style: const TextStyle(color: GwentColors.errorText),
            ),
          },
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text, required this.style, this.leading});

  final String text;
  final TextStyle style;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10,
        children: [
          ?leading,
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w500,
                fontSize: 16,
                height: 1.2,
              ).merge(style),
            ),
          ),
        ],
      ),
    ),
  );
}
