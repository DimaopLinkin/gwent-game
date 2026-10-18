import 'package:flutter/widgets.dart' hide Row;
import 'package:gwent/src/core/presentation/components/player_bar.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_place.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Переводит места сценария в прямоугольники на холсте поля.
///
/// Сценарий называет места по смыслу, а здесь они получают координаты: ряды и руку считает [FieldGeometry], а части
/// полос игроков (лидер, колода, сброс, число карт в руке) измеряются по меткам [PlayerBarAnchors], потому что их
/// положение зависит от того, есть ли справа кнопка «Пас» или метка «Спасовал».
///
/// Место карты в ряду берётся из кадра, а если карты уже нет в ряду (сгорела, ушла в сброс), из памяти: путь призрака
/// начинается там, где карту видели в последний раз.
final class StageGeometry {
  /// Создаёт перевод; [canvas] — метка холста, в чьих координатах нужны прямоугольники.
  StageGeometry({required this.field, required this.canvas, required this.anchors, required this.projection});

  /// Размеры зон поля.
  final FieldGeometry field;

  /// Метка холста поля.
  final GlobalKey canvas;

  /// Метки полос игроков: `true` — моя, `false` — соперника.
  final Map<bool, PlayerBarAnchors> anchors;

  /// Проекция партии после обновления: ряды, которых сценарий не меняет, берутся из неё.
  final PlayerView projection;

  final Map<StagePlace, Rect> _memory = {};

  /// Размер мини-карты, которой рисуются места на полосе.
  static const Size miniSize = Size(31, 44);

  /// Прямоугольник места [place] на момент кадра [frame]; `null`, если места найти нельзя.
  Rect? rectOf(StagePlace place, StageFrame frame) {
    final found = _resolve(place, frame);
    if (found != null) {
      _memory[place] = found;
      return found;
    }
    return _memory[place];
  }

  Rect? _resolve(StagePlace place, StageFrame frame) => switch (place) {
    HandPlace(:final index, :final count) => field.handCardRect(index, count),
    BarHandPlace(:final mine) => _anchor(anchors[mine]?.hand),
    DeckPlace(:final mine) => _anchor(anchors[mine]?.deck),
    DiscardPlace(:final mine) => _anchor(anchors[mine]?.discard),
    LeaderPlace(:final mine) => _anchor(anchors[mine]?.leader),
    BarPlace(:final mine) => mine ? field.myBar : field.opponentBar,
    RowCardPlace(:final mine, :final row, :final card) => _rowCard(mine, row, card, frame),
    RowPlace(:final mine, :final row) => field.rowRect(row, mine: mine),
    HornPlace(:final mine, :final row) => field.hornSlotRect(row, mine: mine),
    WeatherSlotPlace(:final row) => _weatherCard(field.weatherSlotRect(row)),
    CenterPlace() => field.centerCardRect,
    MiniCenterPlace() => Rect.fromCenter(
      center: field.centerCardRect.center,
      width: miniSize.width,
      height: miniSize.height,
    ),
    StripPlace() => field.strip,
    FieldPlace() => Rect.fromLTWH(0, 0, field.width, field.height),
  };

  /// Карта влетает в круг слота погоды, не теряя пропорций: 20×28,7 внутри круга ⌀28.
  Rect _weatherCard(Rect slot) => Rect.fromCenter(center: slot.center, width: 20, height: 20 * 148 / 103);

  Rect? _rowCard(bool mine, Row row, CardInstanceId card, StageFrame frame) {
    final ids =
        frame.rows[(mine: mine, row: row)]?.cards.map((staged) => staged.view.card.id).toList() ??
        [
          for (final view in (mine ? projection.me : projection.opponent).rows[row]?.cards ?? const <FieldCardView>[])
            view.card.id,
        ];
    final index = ids.indexOf(card);
    return index < 0 ? null : field.cardRect(row, index, ids.length, mine: mine);
  }

  /// Метка в координатах холста, приведённая к размеру мини-карты вокруг её центра.
  Rect? _anchor(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    final canvasBox = canvas.currentContext?.findRenderObject();
    if (box is! RenderBox || canvasBox is! RenderBox || !box.attached || !box.hasSize) return null;
    final center = canvasBox.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
    return Rect.fromCenter(center: center, width: miniSize.width, height: miniSize.height);
  }
}
