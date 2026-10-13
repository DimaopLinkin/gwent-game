import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/pending_design_placeholder.dart';

/// Экран настроек. Заглушка до макета настроек и экранов, которые он оформляет.
class SettingsScreen extends StatelessWidget {
  /// Создаёт экран.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.settingsTitle)),
    body: const PendingDesignPlaceholder(),
  );
}
