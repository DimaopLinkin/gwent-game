import 'package:flutter/widgets.dart';

/// Звук нажатия кнопок экранов: [GwentButton] и [ChevronButton] зовут [onPress] перед своим действием.
///
/// Сам звук подставляет точка сборки (`GwentApp`), поэтому общие виджеты ничего не знают о звуковой фиче. Без
/// области (тесты экранов, превью) кнопки молчат.
class ButtonSoundScope extends InheritedWidget {
  /// Создаёт область; [onPress] должен быть одним и тем же объектом между перерисовками, иначе кнопки перестроятся.
  const ButtonSoundScope({super.key, required this.onPress, required super.child});

  /// Игрок нажал кнопку.
  final VoidCallback onPress;

  /// Действие [action] кнопки со звуком нажатия впереди; `null` у недоступной кнопки (она молчит).
  static VoidCallback? wrap(BuildContext context, VoidCallback? action) {
    if (action == null) return null;
    final scope = context.dependOnInheritedWidgetOfExactType<ButtonSoundScope>();
    if (scope == null) return action;
    return () {
      scope.onPress();
      action();
    };
  }

  @override
  bool updateShouldNotify(ButtonSoundScope oldWidget) => onPress != oldWidget.onPress;
}
