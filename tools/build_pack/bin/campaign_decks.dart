import 'dart:convert';
import 'dart:io';

import 'package:gwent_build_pack/gwent_build_pack.dart';

const String _usage = '''
Колоды противников кампании по рецептам из docs/hand/campaign/deck_recipes.json.

  dart run bin/campaign_decks.dart --data <docs/hand/data> --campaign <docs/hand/campaign>

Результат записывается в <campaign>/opponent_decks.json и коммитится: колоды противников фиксированы
(ADR 0033), перегенерация это осознанное решение, после которого повышается pack_version.''';

void main(List<String> args) {
  if (args.length != 4 || args[0] != '--data' || args[2] != '--campaign') {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  try {
    final campaignDir = Directory(args[3]);
    final decks = generateOpponentDecks(tables: readHandTables(Directory(args[1])), campaignDir: campaignDir);
    File(
      '${campaignDir.path}/$campaignDecksFile',
    ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(decks)}\n');
    stdout.writeln('Колоды противников записаны в ${campaignDir.path}/$campaignDecksFile');
  } on HandDataException catch (e) {
    stderr.writeln('Колоды не собраны:');
    e.problems.forEach(stderr.writeln);
    exitCode = 1;
  }
}
