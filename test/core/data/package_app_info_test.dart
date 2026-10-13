import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/data/package_app_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('версия берётся из пакета установки, без номера сборки', () async {
    PackageInfo.setMockInitialValues(
      appName: 'gwent',
      packageName: 'app.gwent',
      version: '1.4.2',
      buildNumber: '77',
      buildSignature: '',
    );

    expect(await const PackageAppInfo().version(), '1.4.2');
  });
}
