import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/adventure.dart';
import '../state/player.dart';
import 'art.dart';
import 'game/local_match_screen.dart';
import 'sky_clouds.dart';
import 'theme.dart';
import 'toast.dart';
import 'top_bar.dart';

/// Écran d'accueil, d'après l'illustration validée (assets/accueil/accueil.png).
///
/// L'image porte le décor, le titre et les cartes des modes. Le code pose par-dessus ce
/// qui change (pseudo, talents, progression de l'aventure, pain quotidien), rend les
/// cartes touchables et les anime : elles s'allument à l'arrivée, l'Aventure respire et un
/// reflet la traverse, une carte touchée se soulève. Les coordonnées ci-dessous sont des
/// pixels de l'image (941 px de large).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _artW = 941.0;
  static const _artH = 1672.0;
  static const _artCut = 152.0; // L'image commence sous ses pastilles du haut (remplacées par la barre).
  static const _navTop = 1526.0; // Barre d'onglets de l'image, de _navTop à _artH.
  static const _logoGlow = Rect.fromLTWH(300, 150, 340, 180);
  static const _adventure = Rect.fromLTWH(28, 583, 888, 384);
  static const _levelPill = Rect.fromLTWH(489, 796, 394, 54);
  static const _starOn = Rect.fromLTWH(745, 801, 44, 42);
  static const _starOff = Rect.fromLTWH(826, 801, 44, 42);
  static const _two = Rect.fromLTWH(28, 1000, 276, 332);
  static const _online = Rect.fromLTWH(330, 1000, 279, 332);
  static const _rooms = Rect.fromLTWH(636, 1000, 280, 332);
  static const _roomsButton = Rect.fromLTWH(680, 1260, 191, 54);
  static const _bread = Rect.fromLTWH(25, 1362, 890, 143);
  static const _breadText = Rect.fromLTWH(298, 1432, 494, 50);
  static const _check = Rect.fromLTWH(794, 1394, 90, 90);
  static const _skyHigh = Color(0xFF1A4FAE);
  static const _skyAtCut = Color(0xFF5F9BF0); // Ciel de l'image à la hauteur _artCut.

  /// Onglets de la barre du bas (abscisses dans l'image) : vide = l'accueil lui-même.
  static const _navTabs = [
    (30.0, 200.0, ''),
    (210.0, 390.0, 'classement'),
    (395.0, 580.0, 'Les récompenses arrivent bientôt.'),
    (585.0, 760.0, 'Les règles du jeu arrivent bientôt.'),
    (765.0, 915.0, 'profil'),
  ];

  ui.Image? _art;
  int _levelCount = 8;

  @override
  void initState() {
    super.initState();
    loadImage(Assets.home).then((img) {
      if (mounted) setState(() => _art = img);
    });
    rootBundle.loadString(Assets.adventure).then((text) {
      final chapters = (jsonDecode(text) as Map<String, dynamic>)['chapitres'] as List? ?? const [];
      final levels = chapters.isEmpty ? null : (chapters.first as Map<String, dynamic>)['niveaux'] as List?;
      if (mounted && levels != null && levels.isNotEmpty) setState(() => _levelCount = levels.length);
    });
  }

  void _toast(String text) => showToast(context, text);

  // Écrans pas encore réécrits en Flutter.
  void _go(String screen) => _toast('« $screen » arrive dans une prochaine étape de la réécriture.');

  @override
  Widget build(BuildContext context) {
    final art = _art;
    final size = MediaQuery.sizeOf(context);
    if (art == null) return const ColoredBox(color: _skyHigh);

    final s = size.width / _artW;
    // L'image entière (barre d'onglets comprise) est calée en bas de l'écran. Un écran plus
    // allongé qu'elle gagne du ciel en haut, où passent des nuages.
    final artH = _artH * s;
    final top = max(size.height - artH, 0.0);
    final skyTop = TopBar.bottom(context);
    final artY = top + _artCut * s;

    Rect r(Rect img) => Rect.fromLTWH(img.left * s, top + img.top * s, img.width * s, img.height * s);
    Widget place(Rect img, Widget child) => Positioned.fromRect(rect: r(img), child: child);
    // Pièce posée sur une carte : rectangle de l'image, relatif à la carte.
    Widget onCard(Rect card, Rect img, Widget child) => Positioned(
          left: (img.left - card.left) * s,
          top: (img.top - card.top) * s,
          width: img.width * s,
          height: img.height * s,
          child: child,
        );
    Widget patch(Color color, double radiusImg, [Widget? child]) => DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radiusImg * s)),
          child: child,
        );
    // Texte calé sur ceux de l'image ; réduit s'il déborde de sa place.
    Widget text(String t, double imgPx, Color color, {int weight = 900}) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(t, maxLines: 1, softWrap: false, style: bodyStyle(imgPx * s, color, weight: weight)),
        );

    return Scaffold(
      backgroundColor: _skyHigh,
      body: ListenableBuilder(
        listenable: Player.instance,
        builder: (context, _) {
          final p = Player.instance;
          final stars = p.isKnown ? p.adventureStars : const <String, List>{};
          final level = Adventure.currentLevel(stars, _levelCount);
          final won = (stars['$level'] ?? const []).length;
          final breadMessage = p.breadGain > 0
              ? 'Tu as reçu ${p.breadGain} talents !'
              : (p.breadToday ? 'Déjà reçu. Reviens demain !' : 'Connecte-toi pour le recevoir.');
          var deal = 0;

          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: artY + 2,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_skyHigh, _skyAtCut],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: skyTop,
                height: max(artY - skyTop + 30 * s, 0),
                child: const SkyClouds(),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: artY,
                height: artH - _artCut * s,
                child: Crop(art, const Rect.fromLTWH(0, _artCut, _artW, _artH - _artCut)),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: artY,
                height: 40 * s,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_skyAtCut, _skyAtCut.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              for (final (x0, x1, message) in _navTabs)
                if (message.isNotEmpty)
                  Positioned(
                    left: x0 * s,
                    top: top + _navTop * s,
                    width: (x1 - x0) * s,
                    height: (_artH - _navTop) * s,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => switch (message) {
                        'classement' => _go('Classement'),
                        'profil' => _go('Profil'),
                        _ => _toast(message),
                      },
                    ),
                  ),
              place(_logoGlow, const _PulsingGlow()),

              // Cartes des modes.
              place(
                _adventure,
                _HomeCard(
                  art: art,
                  region: _adventure,
                  radius: 30 * s,
                  deal: deal++,
                  breathe: true,
                  shine: true,
                  onTap: () => _go('Aventure'),
                  children: [
                    onCard(_adventure, _levelPill, patch(const Color(0xEB171212), 26)),
                    onCard(
                      _adventure,
                      const Rect.fromLTWH(508, 798, 232, 50),
                      text('Genèse, niveau $level/$_levelCount', 25, Palette.cream),
                    ),
                    for (final (i, x) in [745.0, 787.0, 827.0].indexed)
                      onCard(
                        _adventure,
                        Rect.fromLTWH(x, _starOn.top, _starOn.width, _starOn.height),
                        Crop(art, i < won ? _starOn : _starOff),
                      ),
                  ],
                ),
              ),
              place(
                _two,
                _HomeCard(art: art, region: _two, radius: 26 * s, deal: deal++, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalMatchScreen()))),
              ),
              place(
                _online,
                _HomeCard(art: art, region: _online, radius: 26 * s, deal: deal++, onTap: () => _go('En ligne')),
              ),
              place(
                _rooms,
                _HomeCard(
                  art: art,
                  region: _rooms,
                  radius: 26 * s,
                  deal: deal++,
                  onTap: () => _toast('Les salons arrivent bientôt.'),
                  children: [
                    // Mode pas encore disponible : son bouton devient « Bientôt ».
                    onCard(
                      _rooms,
                      _roomsButton,
                      patch(
                        const Color(0xFFF6E4FB),
                        _roomsButton.height / 2,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 30 * s, color: const Color(0xFF33264F)),
                            SizedBox(width: 6 * s),
                            Text('Bientôt', style: bodyStyle(28 * s, const Color(0xFF33264F), weight: 900)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              place(
                _bread,
                _HomeCard(
                  art: art,
                  region: _bread,
                  radius: 18 * s,
                  deal: deal++,
                  onTap: () => _toast('10 talents arrivent chaque jour, à ta première connexion.'),
                  children: [
                    onCard(
                      _bread,
                      _breadText,
                      patch(
                        Palette.parchment,
                        10,
                        Padding(
                          padding: EdgeInsets.only(left: 10 * s),
                          child: text(breadMessage, 27, Palette.ink, weight: 800),
                        ),
                      ),
                    ),
                    onCard(_bread, _check, p.breadToday ? Crop(art, _check) : patch(Palette.parchment, 45)),
                  ],
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: TopBar(onProfile: () => _go('Profil'), onMessage: _toast),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Une carte de l'image, touchable : elle se soulève quand on la touche, s'allume à l'arrivée
/// et peut respirer et être traversée d'un reflet.
class _HomeCard extends StatefulWidget {
  final ui.Image art;
  final Rect region;
  final double radius;
  final int deal;
  final bool breathe;
  final bool shine;
  final VoidCallback onTap;
  final List<Widget> children;

  const _HomeCard({
    required this.art,
    required this.region,
    required this.radius,
    required this.deal,
    required this.onTap,
    this.breathe = false,
    this.shine = false,
    this.children = const [],
  });

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> with TickerProviderStateMixin {
  // Arrivée : les cartes s'allument l'une après l'autre.
  late final _dealIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  // L'Aventure respire doucement (jamais en dessous de sa taille : l'image reste cachée).
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  // Reflet : 2,5 s d'attente puis 1,1 s de passage.
  late final _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  bool _down = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 100 + 120 * widget.deal), () {
      if (mounted) _dealIn.forward();
    });
    if (widget.breathe) _breath.repeat(reverse: true);
    if (widget.shine) _shine.repeat();
  }

  @override
  void dispose() {
    _dealIn.dispose();
    _breath.dispose();
    _shine.dispose();
    super.dispose();
  }

  void _press(bool down) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) {
    final card = Stack(
      fit: StackFit.expand,
      children: [
        Crop(widget.art, widget.region),
        ...widget.children,
        if (widget.shine)
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: CustomPaint(painter: _ShinePainter(_shine)),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          onTap: widget.onTap,
        ),
      ],
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_dealIn, _breath]),
      builder: (context, child) {
        final breath = 1 + 0.015 * Curves.easeInOutSine.transform(_breath.value);
        final t = Curves.easeInOutSine.transform(_dealIn.value);
        Widget result = child!;
        if (t < 1) {
          final (r, g, b) = (1.7 + (1 - 1.7) * t, 1.6 + (1 - 1.6) * t, 1.3 + (1 - 1.3) * t);
          result = ColorFiltered(
            colorFilter: ColorFilter.matrix([r, 0, 0, 0, 0, 0, g, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0]),
            child: result,
          );
        }
        return Transform.scale(scale: breath, child: result);
      },
      child: AnimatedScale(
        scale: _down ? 1.05 : 1,
        duration: Duration(milliseconds: _down ? 120 : 180),
        curve: Curves.easeOutBack,
        child: card,
      ),
    );
  }
}

/// Bande de lumière qui traverse la carte, inclinée de 18°.
class _ShinePainter extends CustomPainter {
  final Animation<double> progress;

  _ShinePainter(this.progress) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    const wait = 2.5 / 3.6;
    final v = progress.value;
    if (v < wait) return;
    final t = Curves.easeInOutSine.transform((v - wait) / (1 - wait));
    final bw = size.width * 0.35;
    final bh = size.height * 1.8;
    final x = -bw * 2 + (size.width * 1.3 + bw * 2) * t;
    canvas.save();
    canvas.translate(x, -size.height * 0.4);
    canvas.rotate(18 * pi / 180);
    final band = Rect.fromLTWH(0, 0, bw, bh);
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x61FFFFFF), Color(0x00FFFFFF)],
        ).createShader(band),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => false;
}

/// Halo doré derrière le logo, qui pulse lentement.
class _PulsingGlow extends StatefulWidget {
  const _PulsingGlow();

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.25).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOutSine)),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.5,
                colors: [Color(0x80FFEBA6), Color(0x00FFEBA6)],
              ),
            ),
          ),
        ),
      );
}
