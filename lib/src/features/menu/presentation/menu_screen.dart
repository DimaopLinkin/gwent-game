import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';

/// Главное меню. Переходы приходят снаружи, поэтому экран не знает о навигации и других фичах.
class MenuScreen extends StatelessWidget {
  /// Создаёт меню.
  const MenuScreen({super.key, required this.onHotSeat, required this.onNetworkGame, required this.onDecks});

  /// Партия на одном телефоне.
  final VoidCallback onHotSeat;

  /// Сетевая игра.
  final VoidCallback onNetworkGame;

  /// Конструктор колоды.
  final VoidCallback onDecks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(l10n.appTitle, style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 16),
              FilledButton(onPressed: onHotSeat, child: Text(l10n.menuHotSeat)),
              FilledButton(onPressed: onNetworkGame, child: Text(l10n.menuNetworkGame)),
              OutlinedButton(onPressed: onDecks, child: Text(l10n.menuDecks)),
            ],
          ),
        ),
      ),
    );
  }
}
