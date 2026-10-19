import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/settings/application/check_content_update.dart';
import 'package:gwent/src/features/settings/application/load_about_info.dart';
import 'package:gwent/src/features/settings/application/save_settings.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/content_update_result.dart';
import 'package:gwent/src/features/settings/presentation/settings_state.dart';

/// Держатель экрана настроек.
///
/// Читает настройки один раз и дальше держит их у себя: экран единственный, кто их меняет, а повторное чтение из
/// хранилища после каждой записи заставило бы ползунок дёргаться. Каждое изменение сразу попадает в состояние и
/// уходит в хранилище. Громкость пишется отдельно, когда игрок отпустил ползунок ([saveVolumes]).
final class SettingsCubit extends Cubit<SettingsState> {
  /// Создаёт держатель и сразу начинает читать настройки.
  ///
  /// Проверка обновления держит состояние «Проверка…» не короче [minCheckDuration]: иначе мгновенный ответ не
  /// заметен и кнопка выглядит сломанной.
  SettingsCubit({
    required WatchSettings watchSettings,
    required SaveSettings saveSettings,
    required LoadAboutInfo loadAboutInfo,
    required CheckContentUpdate checkContentUpdate,
    this.minCheckDuration = const Duration(milliseconds: 800),
  }) : _watchSettings = watchSettings,
       _saveSettings = saveSettings,
       _loadAboutInfo = loadAboutInfo,
       _checkContentUpdate = checkContentUpdate,
       super(const SettingsLoading()) {
    unawaited(_load());
  }

  final WatchSettings _watchSettings;
  final SaveSettings _saveSettings;
  final LoadAboutInfo _loadAboutInfo;
  final CheckContentUpdate _checkContentUpdate;

  /// Наименьшая длительность состояния «Проверка…».
  final Duration minCheckDuration;

  Future<void> _load() async {
    try {
      final settings = await _watchSettings().first;
      final about = await _loadAboutInfo();
      if (!isClosed) emit(SettingsLoaded(settings: settings, about: about));
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const SettingsFailed());
    }
  }

  /// Имя игрока для сетевой игры; пустое имя хранилище сбрасывает.
  void setPlayerName(String name) => _change((settings) => settings.withPlayerName(name));

  /// Подтверждать ли пас.
  void setConfirmPass({required bool value}) => _change((settings) => settings.copyWith(confirmPass: value));

  /// Скорость анимаций.
  void setAnimationSpeed(AnimationSpeed speed) => _change((settings) => settings.copyWith(animationSpeed: speed));

  /// Подсказки для новичка.
  void setHints({required bool value}) => _change((settings) => settings.copyWith(hints: value));

  /// Громкость музыки меняется под пальцем; в хранилище попадёт после [saveVolumes].
  void changeMusicVolume(int volume) => _change((settings) => settings.copyWith(musicVolume: volume), save: false);

  /// Громкость эффектов меняется под пальцем; в хранилище попадёт после [saveVolumes].
  void changeEffectsVolume(int volume) => _change((settings) => settings.copyWith(effectsVolume: volume), save: false);

  /// Игрок отпустил ползунок: сохраняет громкость.
  void saveVolumes() {
    if (state case SettingsLoaded(:final settings)) unawaited(_save(settings));
  }

  /// Проверяет обновление набора карт; пока проверка идёт, повторное нажатие ничего не делает.
  Future<void> checkContentUpdate() async {
    final current = state;
    if (current is! SettingsLoaded || current.update == ContentUpdateStatus.checking) return;
    emit(current.copyWith(update: ContentUpdateStatus.checking));
    final (result, _) = await (_checkContentUpdate(), Future<void>.delayed(minCheckDuration)).wait;
    final latest = state;
    if (isClosed || latest is! SettingsLoaded) return;
    switch (result) {
      case ContentUpToDate(:final checkedAt):
        final settings = latest.settings.copyWith(contentCheckedAt: checkedAt);
        emit(latest.copyWith(settings: settings, update: ContentUpdateStatus.upToDate));
        unawaited(_save(settings));
      case ContentUpdateFailed():
        emit(latest.copyWith(update: ContentUpdateStatus.failed));
    }
  }

  void _change(AppSettings Function(AppSettings settings) transform, {bool save = true}) {
    final current = state;
    if (current is! SettingsLoaded) return;
    final settings = transform(current.settings);
    emit(current.copyWith(settings: settings));
    if (save) unawaited(_save(settings));
  }

  /// Запись в хранилище не ждёт экран; сбой записи уходит в `onError`, а настройка остаётся в состоянии до выхода.
  Future<void> _save(AppSettings settings) async {
    try {
      await _saveSettings(settings);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}
