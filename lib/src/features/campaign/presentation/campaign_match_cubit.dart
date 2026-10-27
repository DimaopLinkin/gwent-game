import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/prepare_campaign_match.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_match_state.dart';

/// Держатель партии узла кампании: готовит запрос и хранит итог, который приходит по концу партии.
///
/// Сама партия идёт в обычных `MatchBloc` и `MatchScreen`, они о кампании ничего не знают.
final class CampaignMatchCubit extends Cubit<CampaignMatchState> {
  /// Создаёт держатель и сразу готовит партию узла [nodeId].
  CampaignMatchCubit(this._prepare, this._campaign, this.nodeId) : super(const CampaignMatchLoading()) {
    unawaited(_begin());
  }

  final PrepareCampaignMatch _prepare;
  final LoadCampaign _campaign;

  /// Узел партии.
  final String nodeId;

  Future<void> _begin() async {
    try {
      final data = await _campaign();
      final result = await _prepare(nodeId, onResult: _onResult, onError: _onError);
      if (isClosed) return;
      emit(switch ((data, result)) {
        (final data?, CampaignMatchPrepared(:final node, :final request)) => CampaignMatchPlaying(
          data: data,
          node: node,
          request: request,
        ),
        (_, CampaignDeckMissing()) => const CampaignMatchNeedsDeck(),
        _ => const CampaignMatchUnavailable(),
      });
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const CampaignMatchUnavailable());
    }
  }

  void _onResult(CampaignResult result) {
    if (isClosed) return;
    if (state case final CampaignMatchPlaying playing) emit(playing.withResult(result));
  }

  void _onError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    if (isClosed) return;
    if (state case final CampaignMatchPlaying playing) emit(playing.withResult(null, failed: true));
  }

  /// Началась новая партия того же узла: итог прежней уже не относится к делу.
  void matchStarted() {
    if (state case final CampaignMatchPlaying playing when playing.result != null || playing.resultFailed) {
      emit(playing.withResult(null));
    }
  }
}
