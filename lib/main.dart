import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/game_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const RopeEscapeApp());
}

class RopeEscapeApp extends StatelessWidget {
  const RopeEscapeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rope Escape',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const GameScreen(),
  );
}
