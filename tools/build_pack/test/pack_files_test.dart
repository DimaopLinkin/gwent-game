import 'dart:convert';
import 'dart:io';

import 'package:gwent_build_pack/gwent_build_pack.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('build_pack_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  Map<String, List<int>> files(String text) => {
    'manifest.json': utf8.encode(text),
    'pack.json': utf8.encode(text),
    'strings.ru.json': utf8.encode(text),
  };

  test('пишет файлы в новую папку и заменяет старый пакет, включая лишний язык', () {
    final out = Directory('${temp.path}/pack');
    writePackFiles(out, files('1'));
    File('${out.path}/strings.en.json').writeAsStringSync('old');
    writePackFiles(out, files('2'));
    expect(out.listSync().map((entry) => entry.uri.pathSegments.last), unorderedEquals(files('2').keys));
    expect(File('${out.path}/pack.json').readAsStringSync(), '2');
  });

  test('не трогает папку, где есть что-то кроме файлов пакета', () {
    File('${temp.path}/notes.txt').writeAsStringSync('важное');
    File('${temp.path}/manifest.json').writeAsStringSync('старый');
    expect(() => writePackFiles(temp, files('1')), throwsA(isA<PackOutputException>()));
    expect(File('${temp.path}/notes.txt').readAsStringSync(), 'важное');
    expect(File('${temp.path}/manifest.json').readAsStringSync(), 'старый');
  });

  test('неверный content_pack.json', () {
    final file = File('${temp.path}/content_pack.json')..writeAsStringSync('{"pack_id": "x", "pack_version": "1"}');
    expect(() => readPackIdentity(file), throwsA(isA<HandDataException>()));
    expect(() => readPackIdentity(File('${temp.path}/missing.json')), throwsA(isA<HandDataException>()));
  });
}
