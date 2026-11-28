import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/state/online.dart';
import 'package:perfectionnement/state/player.dart';
import 'package:perfectionnement/ui/leaderboard/leaderboard_screen.dart';
import 'package:perfectionnement/ui/splash.dart';

import 'local_match_test.dart' show loadFonts, settle;

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> capture(String name) async {
    if (Platform.environment['CAPTURE'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/$name.png'));
    }
  }

  testWidgets('classement : podium, liste et ta ligne', (tester) async {
    phone(tester);
    await tester.runAsync(loadFonts);
    Player.instance.update((p) {
      p.username = 'Semeur870';
      p.xp = 140;
    });
    final rows = [
      for (var i = 1; i <= 14; i++) RankRow(i, 'Joueur_au_long_nom_$i', 3200 - i * 150, false),
    ];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LeaderboardScreen(load: () async => (top: rows, me: const RankRow(23, 'Semeur870', 140, true))),
    ));
    await settle(tester, frames: 6);
    expect(find.text('Classement'), findsOneWidget);
    expect(find.textContaining('pour le Rang S'), findsOneWidget);
    expect(find.text('3 050 XP'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('classement');
  });

  testWidgets('démarrage : se joue puis rend la main, un toucher le passe', (tester) async {
    phone(tester);
    var done = 0;
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: Splash(onDone: () => done++)));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    var elapsed = 0;
    for (final at in const [600, 1100, 1900]) {
      await tester.pump(Duration(milliseconds: at - elapsed));
      elapsed = at;
      await capture('splash_$at');
    }
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(done, 1);
    await tester.pumpWidget(MaterialApp(home: Splash(key: UniqueKey(), onDone: () => done++)));
    await tester.tap(find.byType(Splash));
    expect(done, 2);
    await tester.pumpAndSettle();
  });
}
