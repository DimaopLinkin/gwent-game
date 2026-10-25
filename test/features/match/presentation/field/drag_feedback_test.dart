import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match/presentation/field/drag_feedback.dart';

void main() {
  test('карта на 58 pt выше и на 36 pt левее касания', () {
    expect(DragFeedback.cardOffset(const Offset(200, 500)), const Offset(-36, -58));
    expect(DragFeedback.cardOffset(null), const Offset(-36, -58));
  });

  test('у левого края экрана карта переходит на другую сторону пальца', () {
    expect(DragFeedback.cardOffset(const Offset(30, 500)), const Offset(36, -58));
  });
}
