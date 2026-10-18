import 'package:flutter/material.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

const Color _rowDivider = Color(0xFF2A2118);
const Color _noteText = Color(0xFF8A7D64);

const TextStyle _labelStyle = TextStyle(
  fontFamily: GwentText.alegreya,
  fontWeight: FontWeight.w500,
  fontSize: 17,
  height: 1.2,
  color: GwentColors.textPrimary,
);

/// Группа настроек (макет 10): заголовок капителью и панель со строками, разделёнными тонкой чертой.
class SettingsGroup extends StatelessWidget {
  /// Создаёт группу с заголовком [title] и строками [children].
  const SettingsGroup({super.key, required this.title, required this.children, this.footer});

  /// Заголовок; выводится прописными.
  final String title;

  /// Строки панели.
  final List<Widget> children;

  /// Примечание под панелью.
  final String? footer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Semantics(
          header: true,
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              height: 1,
              letterSpacing: 17 * 0.14,
              color: GwentColors.gold,
            ),
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: GwentColors.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GwentColors.line),
        ),
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) const Divider(height: 1, thickness: 1, color: _rowDivider),
              child,
            ],
          ],
        ),
      ),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            footer!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: GwentText.alegreya,
              fontStyle: FontStyle.italic,
              fontSize: 14,
              height: 1.4,
              color: _noteText,
            ),
          ),
        ),
    ],
  );
}

/// Строка «подпись — значение» (версии, дата). Без значения справа стоит [trailing].
class SettingsValueRow extends StatelessWidget {
  /// Создаёт строку.
  const SettingsValueRow({super.key, required this.label, this.value, this.trailing});

  /// Подпись слева.
  final String label;

  /// Значение справа.
  final String? value;

  /// Виджет справа вместо значения.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 52),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 12,
        children: [
          Expanded(child: Text(label, style: _labelStyle)),
          ?trailing,
          if (value != null)
            Text(
              value!,
              style: _labelStyle.copyWith(height: 1, color: GwentColors.textSecondary),
            ),
        ],
      ),
    ),
  );
}

/// Строка-переключатель: подпись слева, переключатель справа. Нажатие на строку переключает так же, как на сам переключатель.
class SettingsSwitchRow extends StatelessWidget {
  /// Создаёт строку.
  const SettingsSwitchRow({super.key, required this.label, required this.value, required this.onChanged});

  /// Подпись.
  final String label;

  /// Включена ли настройка.
  final bool value;

  /// Игрок переключил.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            spacing: 12,
            children: [
              Expanded(child: Text(label, style: _labelStyle)),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Строка-выбор из нескольких вариантов в «пилюлях»: выбранная золотая, остальные с тонкой рамкой.
class SettingsChoiceRow extends StatelessWidget {
  /// Создаёт строку с заголовком [label] и вариантами [options].
  const SettingsChoiceRow({super.key, required this.label, required this.options});

  /// Заголовок над вариантами.
  final String label;

  /// Варианты по порядку.
  final List<SettingsChoice> options;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(label, style: _labelStyle),
        Row(
          spacing: 8,
          children: [
            for (final option in options)
              Expanded(
                child: GwentButton(
                  label: option.label,
                  semanticsLabel: option.semanticsLabel,
                  height: 44,
                  fontSize: 17,
                  style: option.selected ? GwentButtonStyle.primary : GwentButtonStyle.secondary,
                  onPressed: option.onSelected,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Один вариант [SettingsChoiceRow].
class SettingsChoice {
  /// Создаёт вариант; без [onSelected] он недоступен.
  const SettingsChoice({required this.label, required this.selected, required this.onSelected, this.semanticsLabel});

  /// Подпись.
  final String label;

  /// Подпись для экранного диктора, если она отличается от видимой.
  final String? semanticsLabel;

  /// Выбран ли вариант.
  final bool selected;

  /// Игрок выбрал вариант; `null` — вариант недоступен.
  final VoidCallback? onSelected;
}

/// Строка ползунка: подпись и значение сверху, ползунок под ними.
class SettingsSliderRow extends StatelessWidget {
  /// Создаёт строку.
  const SettingsSliderRow({super.key, required this.label, required this.valueText, required this.slider});

  /// Подпись.
  final String label;

  /// Значение справа от подписи.
  final String valueText;

  /// Сам ползунок.
  final Widget slider;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: _labelStyle),
              Text(valueText, style: _labelStyle.copyWith(fontSize: 15, color: GwentColors.textSecondary)),
            ],
          ),
        ),
        slider,
      ],
    ),
  );
}

/// Строка языка: выбранный отмечен ромбом, недоступные приглушены и помечены [soonLabel].
class SettingsLanguageRow extends StatelessWidget {
  /// Создаёт строку выбранного языка.
  const SettingsLanguageRow.selected({super.key, required this.label}) : soonLabel = null;

  /// Создаёт строку недоступного языка с пометкой [soonLabel].
  const SettingsLanguageRow.soon({super.key, required this.label, required String this.soonLabel});

  /// Название языка.
  final String label;

  /// Пометка недоступного языка; `null` у выбранного.
  final String? soonLabel;

  @override
  Widget build(BuildContext context) {
    final soon = soonLabel;
    return Semantics(
      selected: soon == null,
      enabled: soon == null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(label, style: _labelStyle.copyWith(color: soon == null ? null : GwentColors.muted)),
              ),
              if (soon == null)
                const DiamondMarker(size: 9, color: GwentColors.goldHighlight)
              else
                Text(
                  soon,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    height: 1,
                    color: GwentColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка-переход с шевроном справа («Лицензии шрифтов и библиотек»).
class SettingsLinkRow extends StatelessWidget {
  /// Создаёт строку.
  const SettingsLinkRow({super.key, required this.label, required this.onTap});

  /// Подпись.
  final String label;

  /// Нажатие.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            spacing: 12,
            children: [
              Expanded(child: Text(label, style: _labelStyle)),
              const Text(
                '›',
                style: TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1,
                  color: GwentColors.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
