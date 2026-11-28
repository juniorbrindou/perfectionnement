import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/state/online.dart';
import 'package:perfectionnement/state/player.dart';
import 'package:perfectionnement/ui/profile/profile_screen.dart';

import 'local_match_test.dart' show loadFonts, settle;

void main() {
  // 360 points de large : le plus petit téléphone visé.
  Future<void> open(WidgetTester tester, ProfileView view) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: ProfileScreen(initialView: view)));
    await settle(tester, frames: 5);
  }

  Future<void> capture(String name) async {
    if (Platform.environment['CAPTURE'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/$name.png'));
    }
  }

  setUp(() {
    Online.instance.email = '';
    Online.instance.googleLinked = false;
    Player.instance.update((p) {
      p.connection = Connection.online;
      p.username = 'Semeur870';
      p.xp = 140;
    });
  });

  testWidgets('invité : propose Google, e-mail et la reprise d’un compte', (tester) async {
    await open(tester, ProfileView.profile);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Créer mon compte avec un e-mail'), findsOneWidget);
    expect(find.text('Niveau 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('profil_invite');
    await tester.tap(find.text('Créer mon compte avec un e-mail'));
    await settle(tester, frames: 5);
    expect(find.text('Confirme le mot de passe'), findsOneWidget);
  });

  testWidgets('compte protégé : badge, sans proposition de création', (tester) async {
    Online.instance.googleLinked = true;
    await open(tester, ProfileView.profile);
    expect(find.text('Compte protégé'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsNothing);
    await capture('profil_protege');
  });

  testWidgets('création : mots de passe différents refusés sans appeler le serveur', (tester) async {
    await open(tester, ProfileView.create);
    await tester.enterText(find.byType(TextField).at(0), 'moi@exemple.fr');
    await tester.enterText(find.byType(TextField).at(1), 'motdepasse1');
    await tester.enterText(find.byType(TextField).at(2), 'motdepasse2');
    await tester.ensureVisible(find.text('Créer mon compte').last);
    await tester.tap(find.text('Créer mon compte').last);
    await settle(tester, frames: 5);
    expect(find.text('Les deux mots de passe ne sont pas identiques.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('profil_creation');
  });

  testWidgets('reprise : prévient que le compte invité sera remplacé', (tester) async {
    await open(tester, ProfileView.login);
    expect(find.textContaining('(Semeur870) sera remplacé'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('profil_reprise');
  });

  testWidgets('création : l’œil affiche le mot de passe et les repères suivent la saisie', (tester) async {
    await open(tester, ProfileView.create);
    final champs = find.byType(TextField);
    bool masque(int i) => tester.widget<TextField>(champs.at(i)).obscureText;
    expect(masque(1), isTrue);
    await tester.tap(find.byTooltip('Afficher le mot de passe').first);
    await tester.pump();
    expect(masque(1), isFalse);
    expect(masque(2), isFalse);
    await tester.enterText(champs.at(1), 'motdepasse1');
    await tester.enterText(champs.at(2), 'motde');
    await tester.pump();
    expect(find.text('Pas encore identiques'), findsOneWidget);
    await tester.enterText(champs.at(2), 'motdepasse1');
    await tester.pump();
    expect(find.text('Les mots de passe sont identiques'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('création : clavier ouvert, le bouton reste visible et le champ garde le focus', (tester) async {
    await open(tester, ProfileView.create);
    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 960); // 320 points de clavier
    await settle(tester, frames: 5);
    expect(tester.testTextInput.isVisible, isTrue);
    final bouton = tester.getRect(find.widgetWithText(FilledButton, 'Créer mon compte'));
    expect(bouton.bottom, lessThanOrEqualTo(740 - 320));
    expect(tester.takeException(), isNull);
  });
}
