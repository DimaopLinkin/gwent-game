import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/campaign/application/claim_starting_set.dart';
import 'package:gwent/src/features/campaign/application/load_campaign_overview.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/application/watch_campaign_path.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_state.dart';

/// Держатель тропы кампании (ADR 0033).
///
/// При входе выдаёт стартовый набор тому, кто прошёл «Первую партию» раньше, в «Обучении», и показывает награду. Дальше
/// следит за прогрессом: после каждой записанной победы обзор читается заново. Колода кампании в поток прогресса не
/// входит, поэтому экран просит [refresh], когда вернулся с выбора колоды.
final class CampaignCubit extends Cubit<CampaignState> {
  /// Создаёт держатель и сразу начинает загрузку.
  CampaignCubit(this._watchPath, this._loadOverview, this._claimStartingSet) : super(const CampaignLoading()) {
    unawaited(_start());
  }

  final WatchCampaignPath _watchPath;
  final LoadCampaignOverview _loadOverview;
  final ClaimStartingSet _claimStartingSet;

  StreamSubscription<Object?>? _subscription;
  CampaignWon? _pending;

  Future<void> _start() async {
    try {
      _pending = await _claimStartingSet();
      if (isClosed) return;
      await _reload();
      if (isClosed) return;
      _subscription = _watchPath()
          .skip(1)
          .listen(
            (_) => unawaited(_reload()),
            onError: addError,
          );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const CampaignUnavailable());
    }
  }

  /// Читает обзор заново: колода кампании или прогресс могли измениться.
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    try {
      final overview = await _loadOverview();
      if (isClosed) return;
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
