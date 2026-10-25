import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match/presentation/field/drag_hover.dart';

void main() {
  late List<bool> changes;
  late DragHover hover;

  setUp(() {
    changes = [];
    hover = DragHover(onChanged: ({required over}) => changes.add(over));
    addTearDown(hover.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('вход и выход из цели сообщаются один раз', () async {
    hover.enter();
    await settle();
    expect(hover.value, isTrue);
    hover.leave();
    await settle();
    expect(hover.value, isFalse);
    expect(changes, [true, false]);
  });

  test('переход с цели на цель в одном движении не дребезжит выходом', () async {
    hover.enter();
    await settle();
    hover
      ..leave()
      ..enter();
    await settle();
    expect(hover.value, isTrue);
    expect(changes, [true]);
  });

  test('лишний выход не уходит в минус', () async {
    hover
      ..leave()
      ..enter();
    await settle();
    expect(changes, [true]);
  });

  test('сброс после броска тихий: об отпускании говорит своя вибрация', () async {
    hover.enter();
    await settle();
    hover.reset();
    await settle();
    expect(hover.value, isFalse);
    expect(changes, [true]);
  });

  test('после dispose отложенное решение ничего не делает', () async {
    final local = DragHover(onChanged: ({required over}) => changes.add(over))..enter();
    local.dispose();
    await settle();
    expect(changes, isEmpty);
  });
}
