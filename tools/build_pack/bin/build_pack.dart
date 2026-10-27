import 'dart:io';

import 'package:gwent_build_pack/gwent_build_pack.dart';
import 'package:gwent_content/gwent_content.dart';

const String _usage = '''
Сборка пакета контента из docs/hand/data.

  dart run bin/build_pack.dart --data <docs/hand/data> --identity <docs/hand/content_pack.json> --out <папка пакета>
      [--campaign <docs/hand/campaign>]

С --campaign в пакет входит каталог кампании (campaign.json).

Старые файлы пакета в папке заменяются. Если в папке есть что-то ещё, сборка останавливается,
чтобы не стереть чужие файлы.''';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  try {
    final identity = readPackIdentity(File(options.identity));
    final (built, result) = await buildAndVerify(
      readHandTables(Directory(options.data)),
      identity,
      campaign: options.campaign == null ? null : readCampaignSource(Directory(options.campaign!)),
    );
    switch (result) {
      case PackRejected(:final issues):
        stderr.writeln('Пакет не прошёл проверку:');
        issues.forEach(stderr.writeln);
        exitCode = 1;
      case PackLoaded(:final pack):
        writePackFiles(Directory(options.out), built.files);
        stdout.writeln(
          'Пакет ${pack.manifest.packId} v${pack.manifest.packVersion} (${pack.manifest.contentHash}) '
          'записан в ${options.out}',
        );
    }
  } on HandDataException catch (e) {
    stderr.writeln('Данные docs/hand не конвертируются:');
    e.problems.forEach(stderr.writeln);
    exitCode = 1;
  } on PackOutputException catch (e) {
    stderr.writeln('Пакет не записан: ${e.path}: ${e.message}');
    exitCode = 1;
  }
}

({String data, String identity, String out, String? campaign})? _parseArgs(List<String> args) {
  final values = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    values[args[i]] = args[i + 1];
  }
  final data = values['--data'];
  final identity = values['--identity'];
  final out = values['--out'];
  final campaign = values['--campaign'];
  final expectedLength = campaign == null ? 6 : 8;
  if (args.length != expectedLength || data == null || identity == null || out == null) return null;
  return (data: data, identity: identity, out: out, campaign: campaign);
}
