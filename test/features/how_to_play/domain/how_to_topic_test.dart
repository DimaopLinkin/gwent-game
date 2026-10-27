import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_topic.dart';

void main() {
  test('восемь тем, адреса не повторяются и находятся по имени', () {
    expect(HowToTopic.values, hasLength(8));
    expect({for (final topic in HowToTopic.values) topic.key}, hasLength(8));
    for (final topic in HowToTopic.values) {
      expect(HowToTopic.fromKey(topic.key), topic);
    }
    expect(HowToTopic.fromKey('нет такой'), isNull);
  });

  test('соседние темы идут по порядку, у краёв соседа нет', () {
    expect(HowToTopic.values.first.previous, isNull);
    expect(HowToTopic.values.last.next, isNull);
    for (final topic in HowToTopic.values.skip(1)) {
      expect(topic.previous!.next, topic);
    }
    expect(HowToTopic.goal.next, HowToTopic.handAndDeck);
  });
}
