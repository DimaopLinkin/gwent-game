import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/match_history/application/watch_match_history.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/presentation/history_state.dart';

/// Держатель экрана истории партий: следит за хранилищем и подгружает названия фракций из набора карт.
final class HistoryCubit extends Cubit<HistoryState> {
  /// Создаёт держатель и сразу начинает читать историю и набор карт.
  HistoryCubit(WatchMatchHistory watchMatchHistory, LoadDeckRules loadDeckRules) : super(const HistoryLoading()) {
    _subscription = watchMatchHistory().listen(
      (records) {
        _records = records;
        _emit();
      },
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(HistoryFailed(error));
      },
    );
    unawaited(_loadFactions(loadDeckRules));
  }

  late final StreamSubscription<void> _subscription;
  List<MatchRecord>? _records;
  Map<String, HistoryFaction> _factions = const {};
  bool _factionsDone = false;

  Future<void> _loadFactions(LoadDeckRules loadDeckRules) async {
    try {
      final rules = await loadDeckRules();
      _factions = {
        for (final info in rules.factionInfos) info.id: HistoryFaction(key: info.key, name: info.name),
      };
    } on Object catch (error, stackTrace) {
      // Без набора карт партии видны без названий фракций, реплеи при этом откроются или скажут почему нет.
      addError(error, stackTrace);
    }
    _factionsDone = true;
    _emit();
  }

  void _emit() {
    final records = _records;
    if (records == null || !_factionsDone || isClosed || state is HistoryFailed) return;
    emit(HistoryLoaded(records, factions: _factions));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
