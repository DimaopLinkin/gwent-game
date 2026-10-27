import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/campaign/application/claim_starting_set.dart';
import 'package:gwent/src/features/campaign/application/load_campaign_overview.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/application/sync_campaign_rewards.dart';
import 'package:gwent/src/features/campaign/application/watch_campaign_path.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_state.dart';

/// Держатель тропы кампании (ADR 0033).
///
/// При входе выдаёт стартовый набор тому, кто прошёл «Первую партию» раньше, в «Обучении», и показывает награду, а
/// затем сверяет карты с наградами пройденных узлов (`SyncCampaignRewards`: после смены раздачи наград игрок добирает
/// недостающие копии молча). Дальше следит за прогрессом: после каждой записанной победы обзор читается заново.
/// Колода кампании в поток прогресса не входит, поэтому экран просит [refresh], когда вернулся с выбора колоды.
final class CampaignCubit extends Cubit<CampaignState> {
  /// Создаёт держатель и сразу начинает загрузку.
  CampaignCubit(this._watchPath, this._loadOverview, this._claimStartingSet, this._syncRewards)
    : super(const CampaignLoading()) {
    unawaited(_start());
  }

  final WatchCampaignPath _watchPath;
  final LoadCampaignOverview _loadOverview;
  final ClaimStartingSet _claimStartingSet;
  final SyncCampaignRewards _syncRewards;

  StreamSubscription<Object?>? _subscription;
  CampaignWon? _pending;
  int _loads = 0;

  Future<void> _start() async {
    try {
      _pending = await _claimStartingSet();
    } on Object catch (error, stackTrace) {
      // Набор не выдан сейчас: тропа всё равно открывается, а следующий вход попробует снова (выдача идемпотентна).
      addError(error, stackTrace);
    }
    if (isClosed) return;
    try {
      await _syncRewards();
    } on Object catch (error, stackTrace) {
      // Сверка не удалась: тропа открывается как есть, следующий вход повторит (сверка идемпотентна).
      addError(error, stackTrace);
    }
    if (isClosed) return;
    await _reload();
    if (isClosed) return;
    // Первое значение потока повторяет только что прочитанное обзор; лишнее чтение отбрасывает счётчик загрузок.
    _subscription = _watchPath().listen((_) => unawaited(_reload()), onError: addError);
  }

  /// Читает обзор заново: колода кампании или прогресс могли измениться.
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    // Медленное старое чтение не должно затереть более новое.
    final load = ++_loads;
    try {
      final overview = await _loadOverview();
      if (isClosed || load != _loads) return;
      emit(overview == null ? const CampaignUnavailable() : CampaignReady(overview, pendingReward: _pending));
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && state is CampaignLoading) emit(const CampaignUnavailable());
    }
  }

  /// Игрок посмотрел награду стартового набора.
  void rewardSeen() {
    _pending = null;
    if (state case final CampaignReady ready) emit(ready.withoutReward());
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
