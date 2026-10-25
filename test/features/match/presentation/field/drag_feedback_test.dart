import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match/presentation/field/drag_feedback.dart';

void main() {
  test('мини-карта на 44 pt выше и на 28 pt левее касания', () {
    expect(DragFeedback.cardOffset(const Offset(200, 500)), const Offset(-28, -44));
    expect(DragFeedback.cardOffset(null), const Offset(-28, -44));
  });

  test('у левого края экрана мини-карта переходит на другую сторону пальца', () {
    expect(DragFeedback.cardOffset(const Offset(30, 500)), const Offset(28, -44));
  });
}
