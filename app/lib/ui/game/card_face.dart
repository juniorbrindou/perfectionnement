import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/card_data.dart';
import '../../state/session.dart';
import '../theme.dart';
import 'pictos.dart';

/// Rapport hauteur / largeur des cartes, celui du dos (1 : 1,87).
/// Rapport hauteur / largeur du dos (1 : 1,87, celui de la photo).
const backRatio = 1.87;

/// Face : plus courte que le dos, sans vide sous la dernière réponse (146,4 unités de haut).
const cardRatio = 146.4 / 85;
const cardBackAsset = 'assets/duel/dos_carte_bleu.jpg';
const cardIllustrationAsset = 'assets/duel/dos_illustration.jpg';
const letters = ['A', 'B', 'C', 'D', 'E'];

/// État d'une proposition sur la carte.
enum Mark { none, right, wrong, dim }

const _navyTop = Color(0xFF1D3266);
const _navyBottom = Color(0xFF0C1838);
const _gold = Color(0xFFC9A35A);
const _goldDark = Color(0xFFB8924C);
const _cream = Color(0xFFF3EAD6);
const _encre = Color(0xFF1D2A4A);
const _brun = Color(0xFF3B2A1D);

TextStyle _serif(double size, Color color, {double height = 1.22, int weight = 500}) => TextStyle(
  fontFamily: 'Garamond',
  fontSize: size,
  color: color,
  height: height,
  fontWeight: FontWeight.values[weight ~/ 100 - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
);

/// Plus grande taille de la liste qui fait tenir le texte dans la boîte (la dernière sinon).
double fitSize(
  String text,
  TextStyle style,
  double maxWidth,
  double maxHeight,
  List<double> sizes, {
  int? maxLines,
  TextAlign align = TextAlign.center,
}) => tryFit(text, style, maxWidth, maxHeight, sizes, maxLines: maxLines, align: align) ?? sizes.last;

/// Plus grande taille de la liste qui fait tenir le texte dans la boîte, ou null.
double? tryFit(
  String text,
  TextStyle style,
  double maxWidth,
  double maxHeight,
  List<double> sizes, {
  int? maxLines,
  TextAlign align = TextAlign.center,
}) {
  for (final s in sizes) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontSize: s),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    if (tp.height <= maxHeight && !tp.didExceedMaxLines) return s;
  }
  return null;
}

/// La face d'une carte (modèle docs/maquettes/carte.html). Toutes les mesures suivent la
/// largeur : 1 unité = 1/85 de la carte.
class CardFace extends StatelessWidget {
  final CardData data;
  final List<String> options;
  final double width;

  /// Vue du propriétaire : la bonne réponse est marquée en vert, avec sa lettre.
  final bool owner;
  final Map<String, Mark> marks;
  final String footer;

  /// Vue de celui qui répond : ni livre ni illustration, ils trahiraient souvent la réponse.
  final bool hideBook;
  final ValueChanged<String>? onAnswer;
  final String? bannerTitle;
  final String? bannerText;

  const CardFace({
    super.key,
    required this.data,
    required this.options,
    required this.width,
    this.owner = false,
    this.marks = const {},
    this.footer = 'Ta carte',
    this.hideBook = false,
    this.onAnswer,
    this.bannerTitle,
    this.bannerText,
  });

  @override
  Widget build(BuildContext context) {
    final u = width / 85;
    final art = hideBook ? null : Session.instance.illustration(data.books);
    // Mise en page fixe : la taille du texte réglée dans Android ne doit pas la déborder
    // (les tailles sont calculées pour tenir dans la carte).
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: width,
        height: width * cardRatio,
        child: Stack(
          children: [
            Positioned.fill(child: _Frame(u)),
            Positioned.fill(
              left: 3.7 * u,
              top: 3.7 * u,
              right: 3.7 * u,
              bottom: 3.7 * u,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.4 * u),
                  border: Border.all(color: _gold, width: max(0.2 * u, 0.5)),
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 1.1,
                    colors: [Color(0xFFF8F2E6), Color(0xFFEFE6D4)],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2.2 * u),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: _content(
                      u,
                      art,
                      width < 150 ? (width * 1.2 * MediaQuery.devicePixelRatioOf(context)).round() : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [cache] : largeur de décodage des images, pour les petites cartes (moins de travail à l'écran).
  List<Widget> _content(double u, String? art, int? cache) {
    // Illustration basse : la question a plus de place.
    final illuHeight = 44 * u;
    final question = data.question;
    final qStyle = _serif(6.6 * u, _encre, height: 1.16, weight: 700);
    final qSize = fitSize(question, qStyle, 67.6 * u, 25.5 * u, [
      for (final s in [6.6, 6.0, 5.4, 4.8, 4.3]) s * u,
    ]);
    final shown = [...options];
    return [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: illuHeight,
        child: ClipPath(
          clipper: _IlluClipper(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (art != null)
                Image.asset(
                  art,
                  cacheWidth: cache,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.3),
                  filterQuality: FilterQuality.medium,
                )
              else
                // Le logo du dos, sans son filet, sur la même toile prolongée.
                Image.asset(
                  cardIllustrationAsset,
                  cacheWidth: cache,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.3), // logo remonté
                  filterQuality: FilterQuality.medium,
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.3, 0.75, 1],
                    colors: [Color(0x59060E28), Color(0x00060E28), Color(0x00060E28), Color(0x40060E28)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: illuHeight,
        child: CustomPaint(painter: _IlluEdgePainter(u)),
      ),
      Positioned(
        left: 1.8 * u,
        top: 1.3 * u,
        child: _Round(
          size: 11.4 * u,
          u: u,
          // Réduit si besoin : sur les toutes petites cartes, le cerclage prend sa place.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PictoIcon(pictoForDifficulty(data.difficulty), size: 4.2 * u),
                SizedBox(height: 0.4 * u),
                Text(
                  CardData.difficultyLabels[data.difficulty] == 'Nourriture solide' ? 'Solide' : data.difficultyLabel,
                  style: bodyStyle(2.6 * u, _cream, weight: 700).copyWith(height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        right: 1.1 * u,
        top: 1.9 * u,
        child: _Round(
          size: 9.6 * u,
          u: u,
          translucent: true,
          child: PictoIcon(pictoForCategory(data.category), size: 5.6 * u, stroke: 1.3),
        ),
      ),
      if (!hideBook && data.books.isNotEmpty)
        Positioned(
          left: 0,
          right: 0,
          top: 36.4 * u,
          child: Center(
            child: Container(
              height: 5.8 * u,
              constraints: BoxConstraints(minWidth: 14 * u),
              padding: EdgeInsets.symmetric(horizontal: 3 * u),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2.9 * u),
                gradient: const RadialGradient(center: Alignment(0, -0.4), colors: [_navyTop, _navyBottom]),
                border: Border.all(color: _gold, width: max(0.25 * u, 0.5)),
                boxShadow: [BoxShadow(color: const Color(0x59000000), offset: Offset(0, 0.5 * u), blurRadius: 1.2 * u)],
              ),
              child: Center(
                widthFactor: 1,
                child: Text(data.books.join(' · '), maxLines: 1, style: _serif(3.6 * u, _cream, height: 1)),
              ),
            ),
          ),
        ),
      Positioned(
        left: 5 * u,
        right: 5 * u,
        top: 46.5 * u,
        height: 25.5 * u,
        child: Center(
          child: Text(
            question,
            textAlign: TextAlign.center,
            style: qStyle.copyWith(fontSize: qSize),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 73.8 * u - 0.6 * u,
        height: 1.2 * u,
        child: CustomPaint(painter: _SeparatorPainter(u)),
      ),
      Positioned(
        left: 3.8 * u,
        right: 3.8 * u,
        top: 79.5 * u,
        child: Column(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) SizedBox(height: 2.8 * u),
              AnswerPill(
                u: u,
                letter: letters[i],
                text: shown[i],
                mark: marks[shown[i]] ?? (owner && shown[i] == data.answer ? Mark.right : Mark.none),
                keepLetter: owner,
                onTap: onAnswer == null ? null : () => onAnswer!(shown[i]),
              ),
            ],
          ],
        ),
      ),
      if (bannerTitle != null)
        Positioned(
          left: 6 * u,
          right: 6 * u,
          top: 30 * u, // Sur l’illustration : celui qui répond ne voit pas le livre.
          height: 8.6 * u,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4.3 * u),
              gradient: const RadialGradient(center: Alignment(0, -0.4), colors: [_navyTop, _navyBottom]),
              border: Border.all(color: _gold, width: max(0.25 * u, 0.5)),
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 2 * u),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(bannerTitle!, style: titleStyle(3.4 * u, const Color(0xFFFF9B8E))),
                  SizedBox(width: 1.6 * u),
                  Text(bannerText ?? '', style: bodyStyle(2.6 * u, _cream, weight: 700)),
                ],
              ),
            ),
          ),
        ),
      Positioned(
        left: 3.8 * u,
        right: 3.8 * u,
        top: 135.4 * u,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(data.categoryLabel, style: bodyStyle(2 * u, const Color(0xFF8A7A66), weight: 600)),
            Text(footer, style: bodyStyle(2 * u, const Color(0xFF8A7A66), weight: 600)),
          ],
        ),
      ),
    ];
  }
}

/// Dos de carte : l'image paysage tournée d'un quart de tour.
class CardBack extends StatelessWidget {
  final double width;

  const CardBack({super.key, required this.width});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * backRatio,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(width * 0.04),
      boxShadow: [BoxShadow(color: const Color(0x99000000), offset: Offset(0, width * 0.02), blurRadius: width * 0.05)],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(width * 0.04),
      child: RotatedBox(
        quarterTurns: 1,
        child: Image.asset(cardBackAsset, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
      ),
    ),
  );
}

class _Frame extends StatelessWidget {
  final double u;

  const _Frame(this.u);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4 * u),
      gradient: const RadialGradient(
        center: Alignment(0, -0.2),
        radius: 0.9,
        colors: [Color(0xFF1A2D5C), Color(0xFF0F1C3F)],
      ),
      boxShadow: [BoxShadow(color: const Color(0xB3000000), offset: Offset(0, 1.5 * u), blurRadius: 4 * u)],
    ),
    child: CustomPaint(painter: _FramePainter(u)),
  );
}

/// Toile du cadre et filet doré.
class _FramePainter extends CustomPainter {
  final double u;

  _FramePainter(this.u);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(4 * u));
    canvas.save();
    canvas.clipRRect(outer);
    if (u >= 1.5) {
      final light = Paint()
        ..color = const Color(0x09FFFFFF)
        ..strokeWidth = 0.25 * u;
      final dark = Paint()
        ..color = const Color(0x14000000)
        ..strokeWidth = 0.25 * u;
      for (var y = 0.0; y < size.height; y += 0.5 * u) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), light);
      }
      for (var x = 0.0; x < size.width; x += 0.5 * u) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), dark);
      }
    }
    canvas.restore();
    canvas.drawRRect(
      outer.deflate(0.15 * u),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 * u
        ..color = const Color(0xFF0A1430),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius((Offset.zero & size).deflate(2.3 * u), Radius.circular(3 * u)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.2 * u, 0.5)
        ..color = _goldDark.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.u != u;
}

/// Bord du bas de l'illustration, creusé sous l'étiquette du livre.
Path _illuEdge(Size s, {bool closed = true}) {
  final w = s.width, h = s.height;
  final p = Path();
  if (closed) {
    p
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, 0.925 * h);
  } else {
    p.moveTo(w, 0.925 * h);
  }
  return p
    ..lineTo(0.71 * w, 0.925 * h)
    ..cubicTo(0.65 * w, 0.925 * h, 0.63 * w, h, 0.56 * w, h)
    ..lineTo(0.44 * w, h)
    ..cubicTo(0.37 * w, h, 0.35 * w, 0.925 * h, 0.29 * w, 0.925 * h)
    ..lineTo(0, 0.925 * h);
}

class _IlluClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _illuEdge(size)..close();

  @override
  bool shouldReclip(_IlluClipper old) => false;
}

class _IlluEdgePainter extends CustomPainter {
  final double u;

  _IlluEdgePainter(this.u);

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    _illuEdge(size, closed: false),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.25 * u, 0.5)
      ..color = _gold,
  );

  @override
  bool shouldRepaint(_IlluEdgePainter old) => old.u != u;
}

class _SeparatorPainter extends CustomPainter {
  final double u;

  _SeparatorPainter(this.u);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, half = 25.4 * u;
    final line = Paint()
      ..strokeWidth = max(0.2 * u, 0.4)
      ..shader = const LinearGradient(
        colors: [Color(0x00C9A35A), _gold, _gold, Color(0x00C9A35A)],
        stops: [0, 0.3, 0.7, 1],
      ).createShader(Rect.fromLTWH(cx - half, cy, 2 * half, 1));
    canvas.drawLine(Offset(cx - half, cy), Offset(cx - 3 * u, cy), line);
    canvas.drawLine(Offset(cx + 3 * u, cy), Offset(cx + half, cy), line);
    final d = 0.85 * u;
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - d)
        ..lineTo(cx + d, cy)
        ..lineTo(cx, cy + d)
        ..lineTo(cx - d, cy)
        ..close(),
      Paint()..color = _gold,
    );
  }

  @override
  bool shouldRepaint(_SeparatorPainter old) => old.u != u;
}

/// Rond bleu nuit cerclé d'or (difficulté, catégorie).
class _Round extends StatelessWidget {
  final double size;
  final double u;
  final bool translucent;
  final Widget child;

  const _Round({required this.size, required this.u, required this.child, this.translucent = false});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.2, -0.3),
        colors: translucent
            ? [_navyTop.withValues(alpha: 0.8), _navyBottom.withValues(alpha: 0.8)]
            : [_navyTop, _navyBottom],
      ),
      border: Border.all(color: _gold, width: max(0.25 * u, 0.5)),
      boxShadow: [BoxShadow(color: const Color(0x80000000), offset: Offset(0, 0.5 * u), blurRadius: 1.2 * u)],
    ),
    child: child,
  );
}

/// Une proposition : lettre dans un rond, texte ajusté. Sert sur la carte et ailleurs.
class AnswerPill extends StatefulWidget {
  final double u;
  final String letter;
  final String text;
  final Mark mark;
  final bool keepLetter;
  final VoidCallback? onTap;

  const AnswerPill({
    super.key,
    required this.u,
    required this.letter,
    required this.text,
    this.mark = Mark.none,
    this.keepLetter = false,
    this.onTap,
  });

  @override
  State<AnswerPill> createState() => AnswerPillState();
}

class AnswerPillState extends State<AnswerPill> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final mark = widget.mark;
    final (top, bottom, edge) = switch (mark) {
      Mark.right => (const Color(0xFFEEF8E6), const Color(0xFFD5ECC6), const Color(0xFF5AA55A)),
      Mark.wrong => (const Color(0xFFFBECEA), const Color(0xFFF0D3CF), const Color(0xFFC0544A)),
      _ => (const Color(0xFFFCF9F2), const Color(0xFFEFE7D8), const Color(0xFFCDB894)),
    };
    final (c1, c2, ring) = switch (mark) {
      Mark.right => (const Color(0xFF48A94E), const Color(0xFF24742C), const Color(0xFF1D5E24)),
      Mark.wrong => (const Color(0xFFCF4B3F), const Color(0xFF8E2A22), const Color(0xFF6E1F19)),
      _ => (_navyTop, _navyBottom, _goldDark),
    };
    final Widget inCircle = switch (mark) {
      Mark.wrong => PictoIcon(Picto.non, size: 3 * u, color: Colors.white, stroke: 3.4),
      Mark.right when !widget.keepLetter => PictoIcon(Picto.ok, size: 3 * u, color: Colors.white, stroke: 3.4),
      _ => Text(widget.letter, style: bodyStyle(3.6 * u, Colors.white, weight: 700).copyWith(height: 1)),
    };
    return LayoutBuilder(
      builder: (context, c) => _build(u, mark, top, bottom, edge, c1, c2, ring, inCircle, c.maxWidth - 16.4 * u),
    );
  }

  Widget _build(
    double u,
    Mark mark,
    Color top,
    Color bottom,
    Color edge,
    Color c1,
    Color c2,
    Color ring,
    Widget inCircle,
    double textWidth,
  ) {
    final base = bodyStyle(3.8 * u, _brun, weight: 700).copyWith(height: 1.12);
    final one = tryFit(
      widget.text,
      base,
      textWidth,
      5 * u,
      [3.8 * u, 3.4 * u, 3.1 * u],
      maxLines: 1,
      align: TextAlign.left,
    );
    final lines = one == null ? 2 : 1;
    final size =
        one ??
        fitSize(widget.text, base, textWidth, 8.6 * u, [3.1 * u, 2.8 * u, 2.5 * u], maxLines: 2, align: TextAlign.left);
    final pill = AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        height: 10.8 * u,
        padding: EdgeInsets.only(left: 3.4 * u, right: 3 * u),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5.4 * u),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
          border: Border.all(color: edge, width: max(0.2 * u, 0.5)),
          boxShadow: [
            if (mark == Mark.right) BoxShadow(color: const Color(0x405AA55A), spreadRadius: 0.4 * u),
            BoxShadow(color: const Color(0x38462D0A), offset: Offset(0, 0.7 * u), blurRadius: 1 * u),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 7 * u,
              height: 7 * u,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(center: const Alignment(-0.2, -0.3), colors: [c1, c2]),
                border: Border.all(color: ring, width: max(0.2 * u, 0.4)),
              ),
              child: inCircle,
            ),
            SizedBox(width: 2.8 * u),
            Expanded(
              child: Text(
                widget.text,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
                style: base.copyWith(fontSize: size),
              ),
            ),
          ],
        ),
      ),
    );
    final shown = mark == Mark.dim ? Opacity(opacity: 0.45, child: pill) : pill;
    if (widget.onTap == null) return shown;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: shown,
    );
  }
}
