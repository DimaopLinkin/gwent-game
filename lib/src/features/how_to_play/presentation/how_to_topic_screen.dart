import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_topic.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_illustrations.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_cubit.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_state.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_texts.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_widgets.dart';

/// Страница темы справочника (макет 16, раздел E): абзацы, иллюстрация на настоящих картах, блок «Запомните» и
/// ссылки на соседние темы. Прокручивается; текст растёт вместе с системным шрифтом.
class HowToTopicScreen extends StatelessWidget {
  /// Создаёт страницу темы [topic]; [onBack] возвращает к списку, [onOpen] переходит на соседнюю тему.
  const HowToTopicScreen({super.key, required this.topic, required this.onBack, required this.onOpen});

  /// Тема страницы.
  final HowToTopic topic;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// Игрок перешёл на соседнюю тему.
  final ValueChanged<HowToTopic> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final texts = HowToTexts(topic, l10n);
    final previous = topic.previous;
    final next = topic.next;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(eyebrow: l10n.howToEyebrow, title: texts.title, titleSize: 34, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  for (final paragraph in texts.paragraphs) Text(paragraph, style: howToBodyStyle),
                  BlocBuilder<HowToPlayCubit, HowToPlayState>(
                    builder: (context, state) => switch (state) {
                      HowToPlayReady(:final content) =>
                        howToIllustration(topic, content, l10n) ?? const SizedBox.shrink(),
                      HowToPlayLoading() || HowToPlayUnavailable() => const SizedBox.shrink(),
                    },
                  ),
                  HowToRemember(label: l10n.howToRemember, text: texts.remember),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Expanded(
                        child: previous == null
                            ? const SizedBox.shrink()
                            : _NeighbourLink(
                                label: l10n.howToPreviousTopic,
                                title: HowToTexts(previous, l10n).title,
                                onTap: () => onOpen(previous),
                              ),
                      ),
                      Expanded(
                        child: next == null
                            ? const SizedBox.shrink()
                            : _NeighbourLink(
                                label: l10n.howToNextTopic,
                                title: HowToTexts(next, l10n).title,
                                forward: true,
                                onTap: () => onOpen(next),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeighbourLink extends StatelessWidget {
  const _NeighbourLink({required this.label, required this.title, required this.onTap, this.forward = false});

  final String label;
  final String title;
  final VoidCallback onTap;
  final bool forward;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $title',
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Column(
          crossAxisAlignment: forward ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(
              forward ? '$label ›' : '‹ $label',
              textAlign: forward ? TextAlign.end : TextAlign.start,
              style: const TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.15,
                letterSpacing: 15 * 0.06,
                color: GwentColors.gold,
              ),
            ),
            Text(
              title,
              textAlign: forward ? TextAlign.end : TextAlign.start,
              style: howToBodyStyle.copyWith(fontSize: 15, color: GwentColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}
