import 'package:flutter/material.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

// Сообщение об ошибке на экране партии без макета. Остальные экраны партии лежат в `setup/` (выбор фракции, лидера
// и колоды), `start/` (старт, пересдача) и `overlays/` (итоги, пауза).

/// Действие под сообщением: подпись и нажатие.
typedef MatchAction = ({String label, VoidCallback onPressed, bool primary});

/// Сообщение по центру экрана: заголовок, пояснение, строки и кнопки.
class MatchPanel extends StatelessWidget {
  /// Создаёт панель.
  const MatchPanel({super.key, required this.title, this.body, this.lines = const [], this.actions = const []});

  /// Заголовок.
  final String title;

  /// Пояснение.
  final String? body;

  /// Строки под пояснением, например счёт раундов.
  final List<String> lines;

  /// Кнопки по порядку.
  final List<MatchAction> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Text(title, textAlign: TextAlign.center, style: GwentText.display.copyWith(fontSize: 30)),
            if (body != null) Text(body!, textAlign: TextAlign.center, style: GwentText.body),
            for (final line in lines) Text(line, textAlign: TextAlign.center, style: GwentText.caption),
            for (final action in actions)
              action.primary
                  ? FilledButton(onPressed: action.onPressed, child: Text(action.label))
                  : OutlinedButton(onPressed: action.onPressed, child: Text(action.label)),
          ],
        ),
      ),
    ),
  );
}
