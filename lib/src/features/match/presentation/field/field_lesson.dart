import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/components/player_bar.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Что слой урока знает о поле, чтобы найти места на нём: размеры зон, то, что на экране, и метки частей полос игроков.
@immutable
final class FieldLayout {
  /// Создаёт описание поля.
  FieldLayout({
    required this.fit,
    required this.field,
    required this.view,
    required List<CardInstance> hand,
    required this.anchors,
    required this.handKeys,
  }) : hand = List.unmodifiable(hand);

  /// Как поле вписано в область слоя: координаты слоя равны координатам холста, умноженным на `fit.scale`.
  final FieldFit fit;

  /// Размеры зон поля в координатах холста.
  FieldGeometry get geometry => fit.geometry;

  /// Что выбрал игрок и что поле показывает сейчас.
  final FieldState field;

  /// Проекция, которую рисует поле.
  final PlayerView view;

  /// Карты руки в том порядке, в каком их рисует поле.
  final List<CardInstance> hand;

  /// Метки частей полос игроков: `true` — своя полоса, `false` — соперника.
  final Map<bool, PlayerBarAnchors> anchors;

  /// Метки карт руки по их номеру в партии: показывают, где карта лежит сейчас.
  final Map<CardInstanceId, GlobalKey> handKeys;
}

/// Урок поверх поля (ADR 0034): слой подсказок, пауза урока и лист завершения вместо итога матча.
///
/// Поле ничего не знает об уроке, кроме этого описания: слой строится снаружи, а поле лишь отдаёт ему [FieldLayout].
@immutable
final class FieldLesson {
  /// Создаёт описание урока.
  const FieldLesson({
    required this.layerBuilder,
    required this.finishedBuilder,
    required this.onRestart,
    required this.onExit,
  });

  /// Слой подсказок поверх поля: занимает всю область поля, без системных отступов.
  final Widget Function(BuildContext context, FieldLayout layout) layerBuilder;

  /// Лист завершения вместо итога матча.
  final Widget Function(BuildContext context, MatchFinished finished) finishedBuilder;

  /// «Начать заново» в меню паузы.
  final VoidCallback onRestart;

  /// «В меню» в меню паузы.
  final VoidCallback onExit;
}
