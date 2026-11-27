import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'card_face.dart';

/// Éléments de la table de jeu (docs/maquettes/partie.html, piste A).
/// Les mesures sont celles de la maquette, pour un écran de 360 de large (k = largeur / 360).
double tableUnit(BuildContext context) => MediaQuery.sizeOf(context).width / 360;

const playerColors = [Color(0xFF1FA9A3), Color(0xFF3A6FD8)];
const paleText = Color(0xFFC9D2EE);
const goldLight = Color(0xFFFFE39A);

/// Fond : l'illustration du livre en jeu, floutée et assombrie, ou la nuit.
class GameBackground extends StatelessWidget {
  final String? art;

  const GameBackground({super.key, this.art});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Color(0xFF06122F)),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: art == null
            ? const SizedBox.expand(key: ValueKey('nuit'))
            : ImageFiltered(
                key: ValueKey(art),
                imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6, tileMode: TileMode.decal),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.6, 0, 0, 0, 0, //
                    0, 0.6, 0, 0, 0,
                    0, 0, 0.6, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: // Petite image agrandie : le flou coûte peu, même pendant les changements.
                  Image.asset(
                    art!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    cacheWidth: 160,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            radius: 0.95,
            colors: [Color(0x330B1F4D), Color(0xD906122F)],
          ),
        ),
      ),
    ],
  );
}

/// Bouton doré principal.
class GoldButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  const GoldButton(this.text, {super.key, this.onPressed, this.height = 48, this.fontSize = 20});

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onPressed != null;
    return GestureDetector(
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: on ? (_) => setState(() => _down = false) : null,
      onTapCancel: on ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedOpacity(
        opacity: on ? 1 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: widget.height * 0.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.55, 1],
                colors: [Color(0xFFFFE48A), Color(0xFFF6B92F), Color(0xFFE0961A)],
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF9A5D0E), offset: Offset(0, widget.height * 0.06)),
                BoxShadow(
                  color: const Color(0x73000000),
                  offset: Offset(0, widget.height * 0.12),
                  blurRadius: widget.height * 0.3,
                ),
              ],
            ),
            child: Text(widget.text, style: titleStyle(widget.fontSize, Palette.ink)),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire : verre bleu nuit cerclé d'or.
class NightButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double height;
  final double fontSize;

  const NightButton(this.text, {super.key, required this.onPressed, this.height = 48, this.fontSize = 18});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      height: height,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: height * 0.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: const Color(0xD906122F),
        border: Border.all(color: const Color(0x99F2C14E), width: 1.5),
      ),
      child: Text(text, style: titleStyle(fontSize, goldLight)),
    ),
  );
}

/// Minuteur rond : anneau doré qui se vide, secondes au centre.
class TimerRing extends StatelessWidget {
  final double left;
  final double total;
  final double size;

  const TimerRing({super.key, required this.left, required this.total, required this.size});

  @override
  Widget build(BuildContext context) {
    final urgent = left <= 5;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(total <= 0 ? 0 : (left / total).clamp(0, 1), urgent),
        child: Center(
          child: Text(
            '${left.ceil()}',
            style: titleStyle(size * 0.42, urgent ? const Color(0xFFFFB4A8) : Colors.white).copyWith(
              shadows: const [Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final bool urgent;

  _RingPainter(this.fraction, this.urgent);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r + r * 0.18,
      Paint()
        ..color = const Color(0x40F2C14E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [Color(0xFF183A86), Color(0xFF08173D)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - r * 0.05,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = const Color(0xFFA8741C),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - r * 0.05),
      -pi / 2,
      2 * pi * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round
        ..color = urgent ? const Color(0xFFFF8F7A) : goldLight,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.urgent != urgent;
}

/// Avatar rond cerclé d'or, initiale du joueur.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const PlayerAvatar({super.key, required this.name, required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.06),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF1B8), Color(0xFFF2C14E), Color(0xFFA8741C), Color(0xFFF7D277), Color(0xFF8A5A12)],
      ),
      boxShadow: [BoxShadow(color: const Color(0x80000000), offset: Offset(0, size * 0.07), blurRadius: size * 0.2)],
    ),
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.15)!, Color.lerp(color, Colors.black, 0.4)!],
        ),
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: titleStyle(size * 0.48, Colors.white),
      ),
    ),
  );
}

/// L'adversaire en haut : avatar, nom, état, cartes face cachée.
class OpponentRow extends StatelessWidget {
  final String name;
  final Color color;
  final String status;
  final int cards;
  final double k;

  const OpponentRow({
    super.key,
    required this.name,
    required this.color,
    required this.status,
    required this.cards,
    required this.k,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 14 * k),
    child: Row(
      children: [
        PlayerAvatar(name: name, color: color, size: 40 * k),
        SizedBox(width: 9 * k),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle(15 * k, Colors.white)),
              Text(status, style: bodyStyle(11 * k, goldLight, weight: 800)),
            ],
          ),
        ),
        SizedBox(
          height: 49 * k,
          width: cards == 0 ? 0 : 26 * k + (cards - 1) * 17 * k,
          child: Stack(
            children: [
              for (var i = 0; i < cards; i++)
                Positioned(
                  left: i * 17 * k,
                  child: CardBack(width: 26 * k),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Consigne au centre : une ligne en titre, une ligne d'aide.
class Instruction extends StatelessWidget {
  final String title;
  final String? help;
  final double k;

  const Instruction(this.title, {super.key, this.help, required this.k});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: titleStyle(17 * k, Colors.white).copyWith(
          shadows: const [Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 6)],
        ),
      ),
      if (help != null) Text(help!, textAlign: TextAlign.center, style: bodyStyle(12 * k, paleText, weight: 800)),
    ],
  );
}

/// La main en éventail, cartes ouvertes. La carte choisie se soulève.
class HandFan extends StatelessWidget {
  final int count;
  final Widget Function(int index, double width) card;
  final int selected;
  final ValueChanged<int>? onTap;
  final double k;
  final double height;

  /// Taille des cartes (1 : la main où l’on choisit ; plus petit quand on la regarde seulement).
  final double scale;

  const HandFan({
    super.key,
    required this.count,
    required this.card,
    required this.k,
    required this.height,
    this.scale = 1,
    this.selected = -1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = 54 * k * scale;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final mid = c.maxWidth / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < count; i++)
                () {
                  final off = i - (count - 1) / 2;
                  final lifted = i == selected;
                  return AnimatedPositioned(
                    key: ValueKey(i),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    left: mid + off * 52 * k * scale - w / 2,
                    top: (14 * k + off.abs() * 5 * k - (lifted ? 20 * k : 0)) * scale,
                    child: AnimatedRotation(
                      turns: lifted ? 0 : off * 7 / 360,
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: onTap == null ? null : () => onTap!(i),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(w * 0.05),
                            boxShadow: lifted
                                ? const [
                                    BoxShadow(color: Color(0xFFFFF5C8), spreadRadius: 2),
                                    BoxShadow(color: Color(0xF2FFD66E), blurRadius: 22),
                                  ]
                                : const [],
                          ),
                          child: RepaintBoundary(child: card(i, w)),
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}
