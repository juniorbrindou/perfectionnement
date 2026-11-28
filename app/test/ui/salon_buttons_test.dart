import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/ui/salons/salon_theme.dart';

import 'local_match_test.dart' show loadFonts;

void main() {
  testWidgets('boutons des trois thèmes de salon', (tester) async {
    tester.view.physicalSize = const Size(1080, 900);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: Column(
            children: [
              for (final t in SalonTheme.all)
                Expanded(
                  child: ColoredBox(
                    color: t.background,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SalonButton('Demander à rejoindre', theme: t, onPressed: () {}),
                          const SizedBox(height: 8),
                          SalonButton(
                            'Annuler la demande',
                            theme: t,
                            secondary: true,
                            onPressed: () {},
                            height: 46,
                            fontSize: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalonButton), findsNWidgets(6));
    if (Platform.environment['CAPTURE'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/salon_boutons.png'));
    }
  });
}
