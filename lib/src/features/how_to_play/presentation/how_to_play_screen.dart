import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_topic.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_texts.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_widgets.dart';

/// Список тем справочника «Как играть» (макет 16, раздел E): восемь тем и кнопка «Пройти первую партию» внизу.
///
/// Тексты читаются без набора карт; примеры на картах появляются на страницах тем. Переходы приходят снаружи: экран
/// не знает о маршрутах. Строки растут вместе с системным шрифтом, список прокручивается.
class HowToPlayScreen extends StatelessWidget {
  /// Создаёт экран; [onOpen] открывает тему, [onBack] возвращает назад, [onTutorial] запускает «Первую партию».
  const HowToPlayScreen({super.key, required this.onOpen, required this.onBack, this.onTutorial});

  /// Игрок выбрал тему.
  final ValueChanged<HowToTopic> onOpen;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// «Пройти первую партию»; `null` — кнопки нет (справочник открыт поверх идущей партии).
  final VoidCallback? onTutorial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onTutorial = this.onTutorial;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(eyebrow: l10n.howToEyebrow, title: l10n.howToTitle, titleSize: 34, onBack: onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                for (final topic in HowToTopic.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TopicRow(topic: topic, onOpen: onOpen),
                  ),
                if (onTutorial != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GwentButton(label: l10n.howToStartTutorial, shrinkToFit: true, onPressed: onTutorial),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.onOpen});

  final HowToTopic topic;
  final ValueChanged<HowToTopic> onOpen;

  @override
  Widget build(BuildContext context) {
    final texts = HowToTexts(topic, context.l10n);
    return Semantics(
      button: true,
      label: context.l10n.howToTopicSemantics(texts.title, texts.summary),
      excludeSemantics: true,
      onTap: () => onOpen(topic),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onOpen(topic),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: GwentColors.rowSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: GwentColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(
                spacing: 12,
                children: [
                  HowToCoin(texts.icon),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          texts.title,
                          style: const TextStyle(
                            fontFamily: GwentText.alegreya,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1.15,
                            color: GwentColors.textPrimary,
                          ),
                        ),
                        Text(
                          texts.summary,
                          style: const TextStyle(
                            fontFamily: GwentText.alegreya,
                            fontSize: 15,
                            height: 1.25,
                            color: GwentColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '›',
                    style: TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      height: 1,
                      color: GwentColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
