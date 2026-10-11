import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gwent/src/app/composition_root.dart';
import 'package:gwent/src/app/gwent_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(GwentApp(dependencies: createAppDependencies()));
}
