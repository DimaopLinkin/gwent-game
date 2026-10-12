import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/app/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('лицензии OFL обоих шрифтов зарегистрированы', () async {
    registerFontLicenses();
    final packages = {await for (final entry in LicenseRegistry.licenses) ...entry.packages};
    expect(packages, containsAll(['Alegreya', 'Cormorant SC']));
  });
}
