import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/app/system_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('системные панели прячутся режимом immersiveSticky: по смахиванию от края и снова убираются', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await hideSystemOverlays();

    final modes = calls.where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode');
    expect(modes, hasLength(1));
    expect(modes.single.arguments, 'SystemUiMode.immersiveSticky');
  });
}
