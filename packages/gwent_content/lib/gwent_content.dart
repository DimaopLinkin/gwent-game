/// Пакет контента Гвинта: модели, парсер, канонический JSON, хеш, валидатор, источники и загрузчик.
///
/// Чистый Dart без Flutter и `dart:io`. Используется приложением, утилитами в `tools/` (сборка пакета контента)
/// и валидатором данных. Формат описан в `docs/adr/0002-content-pack.md`.
library;

export 'src/building/content_pack_builder.dart';
export 'src/codec/campaign_codec.dart' show decodeCampaign, encodeCampaign;
export 'src/codec/decode_result.dart';
export 'src/codec/manifest_codec.dart' show decodeManifest, encodeManifest;
export 'src/codec/rules_codec.dart';
export 'src/codec/strings_codec.dart';
export 'src/json/canonical_json.dart';
export 'src/json/sha256_digest.dart';
export 'src/json/uuid.dart';
export 'src/loading/content_pack_loader.dart';
export 'src/loading/pack_load_result.dart';
export 'src/model/ability.dart';
export 'src/model/ability_kind.dart';
export 'src/model/campaign.dart';
export 'src/model/combat_row.dart';
export 'src/model/content_pack.dart';
export 'src/model/effect_key.dart';
export 'src/model/effect_param.dart';
export 'src/model/fraction.dart';
export 'src/model/game_rules.dart';
export 'src/model/leader_card.dart';
export 'src/model/manifest.dart';
export 'src/model/pack_rules.dart';
export 'src/model/param_type.dart';
export 'src/model/raw_params.dart';
export 'src/model/resolved_effect.dart';
export 'src/model/special_card.dart';
export 'src/model/squad_card.dart';
export 'src/model/string_table.dart';
export 'src/model/zone.dart';
export 'src/model/zone_key.dart';
export 'src/pack_format.dart';
export 'src/source/content_source.dart';
export 'src/source/in_memory_content_source.dart';
export 'src/validation/campaign_check.dart' show checkCampaign;
export 'src/validation/content_validator.dart';
export 'src/validation/engine_capabilities.dart';
export 'src/validation/validation_issue.dart';
