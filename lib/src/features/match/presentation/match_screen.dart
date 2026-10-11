import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/pending_design_placeholder.dart';

/// Игровое поле. Заглушка до макетов и движка правил.
class MatchScreen extends StatelessWidget {
  /// Создаёт экран.
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.matchTitle)),
    body: const PendingDesignPlaceholder(),
  );
}
