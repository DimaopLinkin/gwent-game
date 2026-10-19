import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';

/// Всё, что показывает полный просмотр карты: сама карта и пергамент под ней (макет карты, `cardDetailOverlay`).
final class CardDetail {
  /// Создаёт описание карты.
  const CardDetail({required this.face, required this.meta, this.abilities = const [], this.quote});

  /// Карта; её название — заголовок пергамента.
  final CardFace face;

  /// Строка под названием: фракция, ряд, тип.
  final String meta;

  /// Способности по порядку: свойство героя, способность карты, эффект особой карты или способность лидера.
  final List<CardAbilityLine> abilities;

  /// Цитата из игры; `null` — без цитаты.
  final String? quote;
}

/// Строка способности на пергаменте: латунная монета с иконкой, название и описание.
final class CardAbilityLine {
  /// Создаёт строку способности.
  const CardAbilityLine({required this.icon, required this.name, required this.description});

  /// Иконка на монете.
  final GwentIcon icon;

  /// Название.
  final String name;

  /// Что делает способность.
  final String description;
}
