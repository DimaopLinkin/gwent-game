import 'dart:ui' show Color;

import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/features/match/presentation/field/round_summary.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_place.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Ряд одной из сторон.
typedef RowRef = ({bool mine, Row row});

/// Что за число меняется на экране.
enum StageCounter {
  /// Сила ряда (бейдж ряда).
  rowScore,

  /// Общий счёт игрока (круг на полосе).
  total,

  /// Карт в руке.
  hand,

  /// Карт в колоде.
  deck,

  /// Карт в сбросе.
  discard,
}

/// Число на экране: вид, сторона и, для силы ряда, сам ряд.
typedef CounterKey = ({StageCounter kind, bool mine, Row? row});

/// Что нарисовано на летящей карте.
@immutable
sealed class StageCardRef {
  const StageCardRef();
}

/// Лицо карты [card]; пока карта повёрнута рубашкой, видна рубашка колоды владельца ([mine] — моей или соперника).
final class CardFaceRef extends StageCardRef {
  /// Создаёт ссылку.
  const CardFaceRef(this.card, {required this.mine});

  /// Карта.
  final CardInstance card;

  /// Рубашка моей колоды или колоды соперника.
  final bool mine;

  @override
  bool operator ==(Object other) => other is CardFaceRef && other.card == card && other.mine == mine;

  @override
  int get hashCode => Object.hash(card, mine);
}

/// Рубашка колоды игрока: карта, которую не видно (соперник берёт карту из колоды).
final class CardBackRef extends StageCardRef {
  /// Создаёт ссылку.
  const CardBackRef({required this.mine});

  /// Рубашка моей колоды или колоды соперника.
  final bool mine;

  @override
  bool operator ==(Object other) => other is CardBackRef && other.mine == mine;

  @override
  int get hashCode => mine.hashCode ^ 0xB;
}

/// Мини-карта лидера игрока.
final class LeaderRef extends StageCardRef {
  /// Создаёт ссылку.
  const LeaderRef({required this.mine});

  /// Лидер мой или соперника.
  final bool mine;

  @override
  bool operator ==(Object other) => other is LeaderRef && other.mine == mine;

  @override
  int get hashCode => mine.hashCode ^ 0xA;
}

/// Подпись, которая появляется рядом с картой.
enum CaptionKind {
  /// «Противник играет: Название».
  opponentPlays,

  /// «Нет подходящих целей».
  noTargets,

  /// «Скеллиге: две карты вернулись»: способность фракции после раунда.
  perkReturn,
}

/// Вид подсветки места.
enum GlowKind {
  /// Рамка по периметру с мягким свечением внутрь.
  frame,

  /// Заливка цветом.
  wash,

  /// Заливка, которая растёт слева направо на долю [GlowItem.progress].
  sweep,
}

/// Эффект поверх поля в один момент показа. Кадр отдаёт предметы по порядку слоёв: что раньше, то ниже.
@immutable
sealed class StageItem {
  const StageItem();
}

/// Затемнение всего поля (слой 50): смотрим на цели, остальное приглушено.
final class ScrimItem extends StageItem {
  /// Создаёт предмет; [alpha] от 0 до 1.
  const ScrimItem(this.alpha);

  /// Непрозрачность затемнения.
  final double alpha;
}

/// Подсветка места.
final class GlowItem extends StageItem {
  /// Создаёт предмет.
  const GlowItem({
    required this.place,
    required this.color,
    required this.alpha,
    this.kind = GlowKind.frame,
    this.progress = 1,
  });

  /// Что подсвечено.
  final StagePlace place;

  /// Цвет.
  final Color color;

  /// Непрозрачность.
  final double alpha;

  /// Вид.
  final GlowKind kind;

  /// Для [GlowKind.sweep]: доля заполнения.
  final double progress;
}

/// Карта в полёте (слой 60 и выше).
final class CardFlightItem extends StageItem {
  /// Создаёт предмет.
  const CardFlightItem({
    required this.ref,
    required this.from,
    required this.to,
    required this.u,
    required this.arc,
    required this.scale,
    required this.ry,
    required this.shadow,
    required this.size,
    this.opacity = 1,
    this.lift = 0,
  });

  /// Что нарисовано.
  final StageCardRef ref;

  /// Откуда летит.
  final StagePlace from;

  /// Куда летит.
  final StagePlace to;

  /// Доля пути от 0 до 1 (кривая уже применена).
  final double u;

  /// Высота дуги в pt: отрицательная поднимает путь вверх.
  final double arc;

  /// Множитель размера поверх размера места: «карта вырастает на 12 %», посадка 1,1 → 1.
  final double scale;

  /// Поворот вокруг вертикальной оси в градусах: 180 показывает рубашку.
  final double ry;

  /// Сила тени от 0 до 1.
  final double shadow;

  /// Размер, в котором карта нарисована до масштабирования.
  final CardSize size;

  /// Непрозрачность.
  final double opacity;

  /// Подъём карты вверх на lift pt (цели Казни).
  final double lift;
}

/// Подпись рядом с картой, которую показывают крупно.
final class CaptionItem extends StageItem {
  /// Создаёт предмет.
  const CaptionItem({required this.kind, required this.alpha, this.card});

  /// Какая подпись.
  final CaptionKind kind;

  /// Карта, чьё имя в подписи.
  final CardInstance? card;

  /// Непрозрачность.
  final double alpha;
}

/// Волна погоды по ряду.
final class WaveItem extends StageItem {
  /// Создаёт предмет.
  const WaveItem({required this.place, required this.progress, this.reverse = false, this.storm = false});

  /// Ряд.
  final RowPlace place;

  /// Доля пути волны от 0 до 1.
  final double progress;

  /// Волна «выдыхается» справа налево (Ясное небо).
  final bool reverse;

  /// Шторм: две вспышки молнии.
  final bool storm;
}

/// Сгорающая карта на поле.
final class BurnItem extends StageItem {
  /// Создаёт предмет.
  const BurnItem({required this.place, required this.card, required this.target, required this.burn});

  /// Где лежала карта.
  final RowCardPlace place;

  /// Карта.
  final CardInstance card;

  /// Цель выбрана: красная рамка, подъём на 8 pt, от 0 до 1.
  final double target;

  /// Сгорание от 0 до 1: потемнение, огненный фронт снизу вверх, затухание в конце.
  final double burn;
}

/// Пепел от сгоревшей карты.
final class AshItem extends StageItem {
  /// Создаёт предмет.
  const AshItem({required this.place, required this.progress, required this.seed, required this.count});

  /// Где лежала карта.
  final RowCardPlace place;

  /// Доля полёта частиц от 0 до 1.
  final double progress;

  /// Зерно: у каждой карты свой разлёт.
  final int seed;

  /// Сколько частиц.
  final int count;
}

/// Берсерк разворачивается и становится медведем.
final class MorphItem extends StageItem {
  /// Создаёт предмет.
  const MorphItem({required this.place, required this.from, required this.to, required this.progress});

  /// Где лежит карта: место называет карту-цель.
  final RowCardPlace place;

  /// Лицо до превращения.
  final CardInstance from;

  /// Лицо после.
  final CardInstance to;

  /// Доля разворота от 0 до 1; на 0,5 лицо меняется.
  final double progress;
}

/// Подсчёт раунда в центральной полосе: «58 : 41», пока считаются ряды.
final class CountItem extends StageItem {
  /// Создаёт предмет; [winner] выделяет золотом счёт победителя после подсчёта.
  const CountItem({required this.mine, required this.theirs, required this.alpha, this.winner});

  /// Мой счёт.
  final RollValue mine;

  /// Счёт соперника.
  final RollValue theirs;

  /// Непрозрачность.
  final double alpha;

  /// Чей счёт выше; `null`, пока идёт подсчёт.
  final RoundOutcome? winner;
}

/// Плашка итога раунда: полоса поверх поля и строки сработавших способностей фракций.
final class PlaqueItem extends StageItem {
  /// Создаёт предмет.
  const PlaqueItem({required this.summary, required this.scaleY, required this.alpha, required this.marks});

  /// Итог раунда.
  final RoundSummary summary;

  /// Масштаб по высоте: 0,7 → 1 при появлении.
  final double scaleY;

  /// Непрозрачность полосы.
  final double alpha;

  /// Непрозрачность каждой строки способности фракции по порядку.
  final List<double> marks;
}

/// Плашка исхода матча: «Победа», «Поражение» или «Ничья» с числом выигранных раундов.
final class MatchBannerItem extends StageItem {
  /// Создаёт предмет.
  const MatchBannerItem({
    required this.outcome,
    required this.roundsMine,
    required this.roundsTheirs,
    required this.winner,
    required this.scaleY,
    required this.alpha,
  });

  /// Исход для игрока, который смотрит на экран.
  final RoundOutcome outcome;

  /// Раундов выиграл игрок.
  final int roundsMine;

  /// Раундов выиграл соперник.
  final int roundsTheirs;

  /// Победитель матча; `null` при ничьей.
  final Seat? winner;

  /// Масштаб по высоте.
  final double scaleY;

  /// Непрозрачность.
  final double alpha;
}

/// Камни жизни игрока в момент показа: целы [remaining], следующий теряется, [progress] от 0 до 1.
@immutable
final class GemFrame {
  /// Создаёт состояние.
  const GemFrame({required this.remaining, required this.progress});

  /// Сколько камней целы и не затронуты.
  final int remaining;

  /// Как далеко зашла потеря камня номер [remaining]: 0 целый, 1 пустое гнездо.
  final double progress;
}

/// Подсветка силы на карте в ряду.
@immutable
final class CardFlash {
  /// Создаёт подсветку.
  const CardFlash(this.tone, this.alpha);

  /// Цвет.
  final RollTone tone;

  /// Сила от 0 до 1.
  final double alpha;
}

/// Карта в ряду на момент показа.
@immutable
final class StagedCard {
  /// Создаёт карту.
  const StagedCard({required this.view, this.hidden = false, this.opacity = 1});

  /// Карта и её показанная сила.
  final FieldCardView view;

  /// Карта занимает место, но не нарисована: она в полёте или горит.
  final bool hidden;

  /// Непрозрачность при появлении на месте.
  final double opacity;
}

/// Ряд на момент показа.
@immutable
final class StagedRow {
  /// Создаёт ряд.
  const StagedRow({required this.cards, required this.slot, required this.weather});

  /// Карты слева направо, в том числе занявшие место, но ещё не легшие.
  final List<StagedCard> cards;

  /// Слот рога.
  final RowSlot? slot;

  /// Над рядом погода.
  final bool weather;
}

/// Что показывает поле в один момент сценария.
///
/// Всё, чего в кадре нет, поле берёт из проекции партии как есть: сценарий меняет только то, что он описал.
@immutable
final class StageFrame {
  /// Создаёт кадр.
  const StageFrame({
    required this.time,
    this.rows = const {},
    this.counters = const {},
    this.discardTops = const {},
    this.flashes = const {},
    this.handHidden = const {},
    this.handAbsent = const {},
    this.leaderUsed = const {},
    this.weatherSlots = const {},
    this.gems = const {},
    this.shakes = const {},
    this.handVeil = 0,
    this.items = const [],
  });

  /// Момент сценария в миллисекундах.
  final double time;

  /// Ряды, которые сценарий меняет.
  final Map<RowRef, StagedRow> rows;

  /// Числа, которые сценарий прокручивает.
  final Map<CounterKey, RollValue> counters;

  /// Верхняя карта сброса, пока она отличается от проекции; `null` значит сброс пуст.
  final Map<bool, CardInstance?> discardTops;

  /// Подсветка силы карт.
  final Map<CardInstanceId, CardFlash> flashes;

  /// Карты руки, которые ещё летят из колоды.
  final Set<CardInstanceId> handHidden;

  /// Карты руки, которые ещё в колоде: рука для них места не держит и под них не сужена.
  final Set<CardInstanceId> handAbsent;

  /// Способность лидера уже применена (мини-карта приглушена) на этот момент.
  final Map<bool, bool> leaderUsed;

  /// Слоты погоды, которые горят на этот момент: ряды, над которыми лежит погода.
  final Map<Row, bool> weatherSlots;

  /// Камни жизни, которые сценарий показывает по-своему (потеря камня); у остальных камни по проекции.
  final Map<bool, GemFrame> gems;

  /// Смещение полосы игрока по горизонтали, pt: дрожь при потере камня.
  final Map<bool, double> shakes;

  /// Вуаль на руке: ввод заблокирован, рука приглушена; от 0 до 1.
  final double handVeil;

  /// Эффекты поверх поля по слоям.
  final List<StageItem> items;
}
