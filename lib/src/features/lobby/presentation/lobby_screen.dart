import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/pending_design_placeholder.dart';

/// Лобби сетевой игры. Заглушка до макетов и сетевого слоя.
class LobbyScreen extends StatelessWidget {
  /// Создаёт экран.
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.lobbyTitle)),
    body: const PendingDesignPlaceholder(),
  );
}
