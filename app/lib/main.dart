import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state/online.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';
import 'state/sound.dart';
import 'ui/splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Le jeu dessine sous la barre d'état ; ses icônes restent claires sur le bandeau bleu nuit.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Palette.night,
  ));
  // La musique attend la fin de l'animation de démarrage.
  Sound.instance.beginIntro();
  await Sound.instance.start();
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
        home: const _Launch(),
      );
}

/// L'accueil, recouvert au lancement par l'animation de démarrage.
class _Launch extends StatefulWidget {
  const _Launch();

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const HomeScreen(),
          if (!Splash.shown) Positioned.fill(child: Splash(onDone: () => setState(() => Splash.shown = true))),
        ],
      );
}
