import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Регистрирует лицензии OFL шрифтов дизайн-системы, чтобы они попали на экран лицензий.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (package, file) in const [('Alegreya', 'OFL-Alegreya'), ('Cormorant SC', 'OFL-CormorantSC')]) {
      yield LicenseEntryWithLineBreaks([package], await rootBundle.loadString('assets/fonts/$file.txt'));
    }
  });
}
