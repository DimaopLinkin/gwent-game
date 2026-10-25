import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match/presentation/field/drag_hover.dart';

void main() {
  const rowA = 'row-a';
  const rowB = 'row-b';
  late List<bool> changes;
  late int switches;
  late DragHover hover;

  setUp(() {
    changes = [];
    switches = 0;
    hover = DragHover(onChanged: ({required over}) => changes.add(over), onSwitched: () => switches++);
    addTearDown(hover.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('вход и выход из цели сообщаются один раз', () async {
    hover.enter(rowA);
    await settle();
    expect(hover.value, isTrue);
    hover.leave(rowA);
    await settle();
    expect(hover.value, isFalse);
    expect(changes, [true, false]);
    expect(switches, 0, reason: 'первый вход и выход не смена цели');
  });

  test('переход на другую цель в одном движении не дребезжит выходом, но это смена цели', () async {
    hover.enter(rowA);
    await settle();
    hover
      ..leave(rowA)
      ..enter(rowB);
    await settle();
    expect(hover.value, isTrue);
    expect(changes, [true]);
    expect(switches, 1, reason: 'смену цели игрок должен почувствовать');
  });

  test('переход в обратном порядке (сначала вход, потом выход) тоже смена цели', () async {
    hover.enter(rowA);
    await settle();
    hover
      ..enter(rowB)
      ..leave(rowA);
    await settle();
    expect(changes, [true]);
    expect(switches, 1);
  });

  test('выход и вход в ту же цель (палец прошёл по вложенной карте ряда) не смена цели', () async {
    hover.enter(rowA);
    await settle();
    hover
      ..leave(rowA)
      ..enter(rowA);
    await settle();
    expect(hover.value, isTrue);
    expect(changes, [true]);
    expect(switches, 0);
  });

  test('лишний выход чужой цели ничего не ломает', () async {
    hover
      ..leave(rowB)
      ..enter(rowA);
    await settle();
    expect(changes, [true]);
    expect(switches, 0);
  });

  test('сброс после броска тихий: об отпускании говорит своя вибрация', () async {
    hover.enter(rowA);
    await settle();
    hover.reset();
    await settle();
    expect(hover.value, isFalse);
    expect(changes, [true]);
  });

  test('после dispose отложенное решение ничего не делает', () async {
    final local = DragHover(onChanged: ({required over}) => changes.add(over))..enter(rowA);
    local.dispose();
    await settle();
    expect(changes, isEmpty);
  });

  test('target называет цель под пальцем и меняется вместе с ней', () async {
    expect(hover.target.value, isNull);
    hover.enter(rowA);
    await settle();
    expect(hover.target.value, rowA);
    hover
      ..leave(rowA)
      ..enter(rowB);
    await settle();
    expect(hover.target.value, rowB, reason: 'смена цели без выхода в пустоту');
    hover.leave(rowB);
    await settle();
    expect(hover.target.value, isNull);
  });

  test('reset сбрасывает target', () async {
    hover.enter(rowA);
    await settle();
    hover.reset();
    expect(hover.target.value, isNull);
  });
}
