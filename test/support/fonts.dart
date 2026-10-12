import 'package:flutter/services.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Загружает шрифты дизайн-системы из ассетов, чтобы тесты мерили текст настоящими шрифтами.
Future<void> loadDesignFonts() async {
  const families = {
    GwentText.alegreya: [
      'Alegreya-Regular',
      'Alegreya-Italic',
      'Alegreya-Medium',
      'Alegreya-Bold',
      'Alegreya-ExtraBold',
      'Alegreya-Black',
    ],
    GwentText.cormorant: ['CormorantSC-Medium', 'CormorantSC-SemiBold', 'CormorantSC-Bold'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/fonts/$file.ttf'));
    }
    await loader.load();
  }
}
