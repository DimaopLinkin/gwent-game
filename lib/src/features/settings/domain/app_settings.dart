import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:meta/meta.dart';

/// Настройки игрока.
///
/// Новая настройка добавляется полем со значением по умолчанию: хранилище отдаёт его, пока игрок ничего не выбрал.
/// Часть настроек (скорость анимаций, громкость, подсказки, подтверждение паса, имя в сети) хранится заранее:
/// их функции подключаются к игре отдельными задачами, а выбор игрока не теряется.
@immutable
final class AppSettings {
  /// Создаёт настройки.
  const AppSettings({
    this.playerName,
    this.confirmPass = true,
    this.animationSpeed = AnimationSpeed.normal,
    this.hints = true,
    this.musicVolume = defaultMusicVolume,
    this.effectsVolume = defaultEffectsVolume,
    this.contentCheckedAt,
    this.localNetworkExplained = false,
  }) : assert(musicVolume >= 0 && musicVolume <= maxVolume, 'громкость музыки от 0 до $maxVolume'),
       assert(effectsVolume >= 0 && effectsVolume <= maxVolume, 'громкость эффектов от 0 до $maxVolume');

  /// Наибольшая громкость, в процентах.
  static const int maxVolume = 100;

  /// Громкость музыки по умолчанию.
  static const int defaultMusicVolume = 70;

  /// Громкость эффектов по умолчанию.
  static const int defaultEffectsVolume = 85;

  /// Имя игрока, которое видит соперник в сетевой игре. `null`, пока игрок его не задал.
  final String? playerName;

  /// Спрашивать подтверждение паса; иначе пас нужно удерживать.
  final bool confirmPass;

  /// Скорость анимаций партии.
  final AnimationSpeed animationSpeed;

  /// Подсказки для новичка.
  final bool hints;

  /// Громкость музыки, 0–[maxVolume].
  final int musicVolume;

  /// Громкость эффектов, 0–[maxVolume].
  final int effectsVolume;

  /// Когда игрок в последний раз проверял обновление набора карт (UTC). `null`, пока не проверял.
  final DateTime? contentCheckedAt;

  /// Игрок уже видел пояснение перед системным запросом доступа к локальной сети (iOS, ADR 0020).
  final bool localNetworkExplained;

  /// Копия с другим именем игрока; `null` стирает имя.
  AppSettings withPlayerName(String? playerName) => AppSettings(
    playerName: playerName,
    confirmPass: confirmPass,
    animationSpeed: animationSpeed,
    hints: hints,
    musicVolume: musicVolume,
    effectsVolume: effectsVolume,
    contentCheckedAt: contentCheckedAt,
    localNetworkExplained: localNetworkExplained,
  );

  /// Копия с другими значениями; не названные поля остаются прежними. Имя игрока меняет [withPlayerName].
  AppSettings copyWith({
    bool? confirmPass,
    AnimationSpeed? animationSpeed,
    bool? hints,
    int? musicVolume,
    int? effectsVolume,
    DateTime? contentCheckedAt,
    bool? localNetworkExplained,
  }) => AppSettings(
    playerName: playerName,
    confirmPass: confirmPass ?? this.confirmPass,
    animationSpeed: animationSpeed ?? this.animationSpeed,
    hints: hints ?? this.hints,
    musicVolume: musicVolume ?? this.musicVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
    contentCheckedAt: contentCheckedAt ?? this.contentCheckedAt,
    localNetworkExplained: localNetworkExplained ?? this.localNetworkExplained,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.playerName == playerName &&
      other.confirmPass == confirmPass &&
      other.animationSpeed == animationSpeed &&
      other.hints == hints &&
      other.musicVolume == musicVolume &&
      other.effectsVolume == effectsVolume &&
      other.contentCheckedAt == contentCheckedAt &&
      other.localNetworkExplained == localNetworkExplained;

  @override
  int get hashCode => Object.hash(
    playerName,
    confirmPass,
    animationSpeed,
    hints,
    musicVolume,
    effectsVolume,
    contentCheckedAt,
    localNetworkExplained,
  );

  @override
  String toString() =>
      'AppSettings(playerName: $playerName, confirmPass: $confirmPass, animationSpeed: $animationSpeed, '
      'hints: $hints, musicVolume: $musicVolume, effectsVolume: $effectsVolume, contentCheckedAt: $contentCheckedAt, '
      'localNetworkExplained: $localNetworkExplained)';
}
