import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art.dart';

/// Les trois ambiances d'un salon (docs/maquettes/salons_ambiances.html), choisies par son Berger.
/// Chaque décor est un morceau d'illustration sans visage.
class SalonTheme {
  final String id;
  final String name;
  final bool dark;
  final Color background;
  final Color title;
  final Color text;
  final Color soft;
  final Color accent;
  final Color card;
  final Color cardEdge;
  final String art;

  /// Rectangle de l'illustration (1152 × 768) montré en haut de l'écran.
  final Rect header;

  /// Morceau montré en bas de l'écran (la table garnie du repas de fête), ou null.
  final Rect? footer;

  const SalonTheme({
    required this.id,
    required this.name,
    required this.dark,
    required this.background,
    required this.title,
    required this.text,
    required this.soft,
    required this.accent,
    required this.card,
    required this.cardEdge,
    required this.art,
    required this.header,
    this.footer,
  });

  static const fete = SalonTheme(
    id: 'fete',
    name: 'Repas de fête',
    dark: true,
    background: Color(0xFF2E1A33),
    title: Color(0xFFFFE3B0),
    text: Color(0xFFFBEFDC),
    soft: Color(0xFFD8B88F),
    accent: Color(0xFFF2B65A),
    card: Color(0x24FFD696),
    cardEdge: Color(0x47F2B65A),
    art: 'assets/illustrations/jean.jpg',
    header: Rect.fromLTWH(760, 0, 392, 190),
    footer: Rect.fromLTWH(0, 590, 560, 178),
  );

  static const paturages = SalonTheme(
    id: 'paturages',
    name: 'Verts pâturages',
    dark: false,
    background: Color(0xFFF6F1DF),
    title: Color(0xFF2F4A2A),
    text: Color(0xFF2F3A2A),
    soft: Color(0xFF7F8A6C),
    accent: Color(0xFF4F7A4A),
    card: Color(0xFFFFFDF4),
    cardEdge: Color(0xFFE3DCC2),
    art: 'assets/illustrations/psaumes.jpg',
    header: Rect.fromLTWH(670, 60, 482, 401),
  );

  static const jardin = SalonTheme(
    id: 'jardin',
    name: 'Jardin au matin',
    dark: false,
    background: Color(0xFFEEF3EE),
    title: Color(0xFF1D3A5A),
    text: Color(0xFF1D2A4A),
    soft: Color(0xFF6F8290),
    accent: Color(0xFF2A5A7A),
    card: Color(0xD9FFFFFF),
    cardEdge: Color(0xFFD6E2E4),
    art: 'assets/illustrations/genese.jpg',
    header: Rect.fromLTWH(300, 40, 552, 460),
  );

  static const all = [fete, paturages, jardin];

  static SalonTheme of(String id) => all.firstWhere((t) => t.id == id, orElse: () => fete);
}

/// Couleurs des écus.
const salonColors = [
  Color(0xFF6B8F4E),
  Color(0xFF3D6F8E),
  Color(0xFFB0613A),
  Color(0xFF7A5A9E),
  Color(0xFFA8742A),
  Color(0xFF8E2A22),
];

Color salonColor(int i) => salonColors[i.clamp(0, salonColors.length - 1)];

/// Le décor d'un thème : l'illustration en haut, qui se fond dans la couleur du fond, et le
/// morceau du bas s'il y en a un.
class SalonBackdrop extends StatefulWidget {
  final SalonTheme theme;
  final double headerHeight;
  final Widget child;

  const SalonBackdrop({super.key, required this.theme, required this.headerHeight, required this.child});

  @override
  State<SalonBackdrop> createState() => _SalonBackdropState();
}

class _SalonBackdropState extends State<SalonBackdrop> {
  static final Map<String, Future<ui.Image>> _cache = {};
  ui.Image? _art;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SalonBackdrop old) {
    super.didUpdateWidget(old);
    if (old.theme.art != widget.theme.art) _load();
  }

  void _load() {
    final art = widget.theme.art;
    (_cache[art] ??= loadImage(art)).then((img) {
      if (mounted && widget.theme.art == art) setState(() => _art = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final art = _art;
    final footer = t.footer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: t.background,
      child: Stack(
        children: [
          if (art != null) ...[
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: widget.headerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Cover(image: art, region: t.header),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.45, 0.98],
                        colors: [
                          t.background.withValues(alpha: t.dark ? 0.05 : 0),
                          t.background.withValues(alpha: t.dark ? 0.3 : 0),
                          t.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (footer != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.headerHeight * 0.62,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Cover(image: art, region: footer),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [t.background, t.background.withValues(alpha: 0.35), t.background.withValues(alpha: 0.1)],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

/// Un rectangle de l'image, recadré pour couvrir la place (comme BoxFit.cover).
class _Cover extends StatelessWidget {
  final ui.Image image;
  final Rect region;

  const _Cover({required this.image, required this.region});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final boxRatio = c.maxWidth / c.maxHeight;
          var r = region;
          if (r.width / r.height > boxRatio) {
            final w = r.height * boxRatio;
            r = Rect.fromLTWH(r.left + (r.width - w) / 2, r.top, w, r.height);
          } else {
            final h = r.width / boxRatio;
            r = Rect.fromLTWH(r.left, r.top, r.width, h);
          }
          return Crop(image, r);
        },
      );
}

/// Vignette d'un thème (choix du thème à la création).
class SalonThemeThumb extends StatefulWidget {
  final SalonTheme theme;

  const SalonThemeThumb({super.key, required this.theme});

  @override
  State<SalonThemeThumb> createState() => _SalonThemeThumbState();
}

class _SalonThemeThumbState extends State<SalonThemeThumb> {
  ui.Image? _art;

  @override
  void initState() {
    super.initState();
    final art = widget.theme.art;
    (_SalonBackdropState._cache[art] ??= loadImage(art)).then((img) {
      if (mounted) setState(() => _art = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    return art == null ? ColoredBox(color: widget.theme.background) : _Cover(image: art, region: widget.theme.header);
  }
}
