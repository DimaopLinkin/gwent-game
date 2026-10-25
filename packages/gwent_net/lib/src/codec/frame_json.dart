import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/codec/event_json.dart';
import 'package:gwent_net/src/codec/json_reader.dart';
import 'package:gwent_net/src/codec/view_json.dart';

/// Кадр партии глазами одного игрока: проекция после хода и события, которые игрок увидел.
typedef ViewFrame = ({PlayerView view, List<GameEvent> events});

/// JSON кадра партии: для записи, которую ведёт устройство, у которого журнала нет (гость в сетевой партии).
Map<String, Object?> encodeViewFrame(ViewFrame frame) => {
  'view': encodeView(frame.view),
  'events': [for (final event in frame.events) encodeEvent(event)],
};

/// Кадр из JSON; ошибки формата — `MalformedFrame` с путём к полю.
ViewFrame decodeViewFrame(Object? json) {
  final r = JsonReader(json, r'$');
  return (view: decodeView(r.object('view')), events: r.objects('events', decodeEvent));
}
