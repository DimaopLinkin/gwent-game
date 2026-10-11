import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_engine/src/core/value.dart';

/// Генератор с заранее заданными числами: тест сам решает, что выпадет.
final class ScriptedRng extends Value implements Rng {
  const ScriptedRng(this.values);

  final List<int> values;

  @override
  (int, Rng) nextInt(int max) {
    if (values.isEmpty) throw StateError('Сценарий генератора исчерпан');
    final value = values.first;
    if (value >= max) throw StateError('Сценарий дал $value, а нужно меньше $max');
    return (value, ScriptedRng(values.sublist(1)));
  }

  @override
  List<Object?> get props => [values];
}
