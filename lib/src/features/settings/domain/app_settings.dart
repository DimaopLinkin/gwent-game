import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:meta/meta.dart';

/// Настройки игрока.
///
/// Новая настройка добавляется полем со значением по умолчанию: хранилище отдаёт его, пока игрок ничего не выбрал.
/// Часть настроек (подтверждение паса, имя в сети) хранится заранее:
/// их функции подключаются к игре отдельными задачами, а выбор игрока не теряется.
@immutable
final class AppSettings {
  /// Создаёт настройки.
  const AppSettings({
    this.playerName,
    this.confirmPass = true,
    this.animationSpeed = AnimationSpeed.normal,
    this.hints = true,
    this.haptics = true,
    this.musicVolume = defaultMusicVolume,
    this.effectsVolume = defaultEffectsVolume,
    this.contentCheckedAt,
    this.botDifficulty = BotDifficulty.normal,
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

  /// Подсказки для новичка: в партии статичная строка в центральной полосе подсказывает, что делать с выбранной
  /// картой (ADR 0010).
  final bool hints;

  /// Вибрация в партии и при прицеливании (ADR 0031).
  final bool haptics;

  /// Громкость музыки, 0–[maxVolume].
  final int musicVolume;

  /// Громкость эффектов, 0–[maxVolume].
  final int effectsVolume;

  /// Когда игрок в последний раз проверял обновление набора карт (UTC). `null`, пока не проверял.
  final DateTime? contentCheckedAt;

  /// Уровень сложности бота, выбранный в прошлый раз: в следующей партии против бота он выбран заранее.
  final BotDifficulty botDifficulty;

  /// Игрок уже видел пояснение перед системным запросом доступа к локальной сети (iOS, ADR 0020).
  final bool localNetworkExplained;

  /// Копия с другим именем игрока; `null` стирает имя.
  AppSettings withPlayerName(String? playerName) => AppSettings(
    playerName: playerName,
    confirmPass: confirmPass,
    animationSpeed: animationSpeed,
    hints: hints,
    haptics: haptics,
    musicVolume: musicVolume,
    effectsVolume: effectsVolume,
    contentCheckedAt: contentCheckedAt,
    botDifficulty: botDifficulty,
    localNetworkExplained: localNetworkExplained,
  );

  /// Копия с другими значениями; не названные поля остаются прежними. Имя игрока меняет [withPlayerName].
  AppSettings copyWith({
    bool? confirmPass,
    AnimationSpeed? animationSpeed,
    bool? hints,
    bool? haptics,
    int? musicVolume,
    int? effectsVolume,
    DateTime? contentCheckedAt,
    BotDifficulty? botDifficulty,
    bool? localNetworkExplained,
  }) => AppSettings(
    playerName: playerName,
    confirmPass: confirmPass ?? this.confirmPass,
    animationSpeed: animationSpeed ?? this.animationSpeed,
    hints: hints ?? this.hints,
    haptics: haptics ?? this.haptics,
    musicVolume: musicVolume ?? this.musicVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
    contentCheckedAt: contentCheckedAt ?? this.contentCheckedAt,
    botDifficulty: botDifficulty ?? this.botDifficulty,
    localNetworkExplained: localNetworkExplained ?? this.localNetworkExplained,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.playerName == playerName &&
      other.confirmPass == confirmPass &&
      other.animationSpeed == animationSpeed &&
      other.hints == hints &&
      other.haptics == haptics &&
      other.musicVolume == musicVolume &&
      other.effectsVolume == effectsVolume &&
      other.contentCheckedAt == contentCheckedAt &&
      other.botDifficulty == botDifficulty &&
      other.localNetworkExplained == localNetworkExplained;

  @override
  int get hashCode => Object.hash(
    playerName,
    confirmPass,
    animationSpeed,
    hints,
    haptics,
    musicVolume,
    effectsVolume,
    contentCheckedAt,
    botDifficulty,
    localNetworkExplained,
  );

  @override
  String toString() =>
      'AppSettings(playerName: $playerName, confirmPass: $confirmPass, animationSpeed: $animationSpeed, '
      'hints: $hints, haptics: $haptics, musicVolume: $musicVolume, effectsVolume: $effectsVolume, contentCheckedAt: $contentCheckedAt, '
      'botDifficulty: $botDifficulty, '
      'localNetworkExplained: $localNetworkExplained)';
}
