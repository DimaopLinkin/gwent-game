import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gwent/src/app/composition_root.dart';
import 'package:gwent/src/app/font_licenses.dart';
import 'package:gwent/src/app/gwent_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(GwentApp(dependencies: createAppDependencies()));
}
