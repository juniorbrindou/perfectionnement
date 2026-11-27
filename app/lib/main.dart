import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state/online.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Le jeu dessine sous la barre d'état ; ses icônes restent claires sur le bandeau bleu nuit.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Palette.night,
  ));
  runApp(const PerfectionnementApp());
  // Compte gardé sur le téléphone, puis connexion au serveur en invité.
  Online.instance.start();
}

class PerfectionnementApp extends StatelessWidget {
  const PerfectionnementApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Perfectionnement',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Palette.gold, brightness: Brightness.dark),
          fontFamily: 'Nunito',
        ),
        home: const HomeScreen(),
      );
}
