import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_state.dart';

/// Конструктор колоды. Пока показывает только сохранённые колоды; экран свёрстывается по макетам.
///
/// Ждёт [DeckListCubit] выше по дереву.
class DeckBuilderScreen extends StatelessWidget {
  /// Создаёт экран.
  const DeckBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.deckBuilderTitle)),
    body: BlocBuilder<DeckListCubit, DeckListState>(
      builder: (context, state) => switch (state) {
        DeckListLoading() => const Center(child: CircularProgressIndicator()),
        DeckListFailed() => Center(child: Text(context.l10n.deckListLoadFailed)),
        DeckListLoaded(decks: []) => Center(child: Text(context.l10n.deckListEmpty)),
        DeckListLoaded(:final decks) => ListView.builder(
          itemCount: decks.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(decks[index].name),
            subtitle: Text(context.l10n.deckCardCount(decks[index].cardCount)),
          ),
        ),
      },
    ),
  );
}
