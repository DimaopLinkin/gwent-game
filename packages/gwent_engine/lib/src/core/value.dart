import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Неизменяемое значение со структурным равенством.
///
/// Наследник перечисляет поля в [props]; списки и словари сравниваются поэлементно.
/// Это нужно тестам детерминизма: одинаковый сид и одинаковые намерения обязаны дать равные состояния.
@immutable
abstract class Value {
  const Value();

  /// Поля, из которых складывается равенство.
  List<Object?> get props;

  static const DeepCollectionEquality _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Value && other.runtimeType == runtimeType && _equality.equals(other.props, props);

  @override
  int get hashCode => Object.hash(runtimeType, _equality.hash(props));

  /// Строка для отладки и сообщений тестов; логика на неё не опирается.
  @override
  String toString() => '$runtimeType$props';
}
