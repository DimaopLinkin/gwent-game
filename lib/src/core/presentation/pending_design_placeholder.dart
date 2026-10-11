import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';

/// Тело экрана, который ещё не свёрстан по макетам.
class PendingDesignPlaceholder extends StatelessWidget {
  /// Создаёт заглушку.
  const PendingDesignPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(context.l10n.screenPendingDesign, style: Theme.of(context).textTheme.bodyLarge),
  );
}
