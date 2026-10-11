import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await AppDatabase.initPlatform();
  final repo = LedgerRepository();
  final state = AppState(repo);
  await state.init();
  runApp(QingshuangApp(state: state));
}
