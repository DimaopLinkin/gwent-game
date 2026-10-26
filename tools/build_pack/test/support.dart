import 'dart:io';

import 'package:gwent_build_pack/gwent_build_pack.dart';
import 'package:gwent_content/gwent_content.dart';

/// Папка `docs/hand` репозитория (тесты запускаются из `tools/build_pack`).
final Directory handDir = Directory('../../docs/hand');

/// Таблицы `docs/hand/data`, свежая копия на каждый вызов.
Map<String, Object?> realTables() => readHandTables(Directory('${handDir.path}/data'));

/// Идентичность пакета из `docs/hand/content_pack.json`.
PackIdentity realIdentity() => readPackIdentity(File('${handDir.path}/content_pack.json'));

/// Папка данных кампании `docs/hand/campaign`.
final Directory campaignDir = Directory('${handDir.path}/campaign');

/// Данные кампании из `docs/hand/campaign`.
CampaignSource realCampaignSource() => readCampaignSource(campaignDir)!;
