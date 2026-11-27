import 'dart:math';

import 'package:flutter/material.dart';

import '../core/progression.dart';
import '../state/player.dart';
import 'art.dart';
import 'theme.dart';

/// Barre du haut commune (accueil, aventure…) : un bandeau bleu nuit d'un bord à l'autre,
/// collé en haut de l'écran sous la barre d'état d'Android (référence validée le 2026-11-23).
/// Elle porte l'avatar, le pseudo, le niveau et sa barre d'XP, les talents et le réglage, et
/// se met à jour seule avec le compte. Les coordonnées sont des pixels de l'image d'accueil
/// (941 px de large), mise à la largeur de l'écran.
class TopBar extends StatelessWidget {
  static const artWidth = 941.0;
  static const bandHeight = 146.0;
  static const _bandY = 6.0; // Haut du bandeau dans l'image : les rectangles ci-dessous en partent.
  static const _avatar = Rect.fromLTWH(46, 18, 124, 124);
  static const _profileTap = Rect.fromLTWH(40, 18, 444, 124);
  static const _xpBar = Rect.fromLTWH(200, 126, 230, 8);
  static const _talentPill = Rect.fromLTWH(580, 32, 250, 92);
  static const _gear = Rect.fromLTWH(842, 35, 74, 74);
  static const _shadow = 16.0;

  final VoidCallback onProfile;
  final void Function(String) onMessage;

  const TopBar({super.key, required this.onProfile, required this.onMessage});

  /// Bas du bandeau, en pixels de l'écran.
  static double bottom(BuildContext context) =>
      MediaQuery.paddingOf(context).top + bandHeight * MediaQuery.sizeOf(context).width / artWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final s = width / artWidth;
    final safe = MediaQuery.paddingOf(context).top;
    final bandBottom = safe + bandHeight * s;
    final u = unit(context);

    Widget put(Rect r, Widget child) => Positioned(
          left: r.left * s,
          top: safe + (r.top - _bandY) * s,
          width: r.width * s,
          height: r.height * s,
          child: child,
        );
    Widget text(String t, double imgPx, Color color) => Align(
          alignment: Alignment.centerLeft,
          child: Text(t, maxLines: 1, softWrap: false, style: bodyStyle(imgPx * s, color, weight: 900)),
        );
    Widget tap(Rect r, VoidCallback action) =>
        put(r, GestureDetector(behavior: HitTestBehavior.opaque, onTap: action));

    return ListenableBuilder(
      listenable: Player.instance,
      builder: (context, _) {
        final p = Player.instance;
        final known = p.isKnown;
        final name = known ? p.username : (p.connection == Connection.connecting ? 'Connexion…' : 'Hors ligne');
        final level = Progression.fromXp(known ? p.xp : 0);
        final ratio = level.inLevel / level.toNext;
        return SizedBox(
          width: width,
          height: bandBottom + _shadow * s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: bandBottom,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1C3672), Color(0xFF0E1F4C)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: bandBottom - max(2, 2 * s),
                height: max(2, 2 * s),
                child: const ColoredBox(color: Color(0x8CC99A3C)),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: bandBottom,
                height: _shadow * s,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x59000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              put(const Rect.fromLTWH(196, 34, 330, 44), text(name, 34, Colors.white)),
              put(const Rect.fromLTWH(198, 86, 36, 32), Image.asset(Assets.crown, fit: BoxFit.contain)),
              put(
                const Rect.fromLTWH(242, 84, 300, 36),
                Row(children: [
                  Text('Niveau ${level.level}', style: bodyStyle(27 * s, Palette.gold, weight: 900)),
                  if (known && Progression.hasRankS(p.rankPlace)) ...[
                    SizedBox(width: 6 * s),
                    RankSBadge(side: 14 * u),
                  ],
                ]),
              ),
              put(
                _xpBar,
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x24FFFFFF),
                    borderRadius: BorderRadius.circular(4 * s),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ratio > 0
                        ? Container(
                            // Un minimum visible, pour que la barre ne paraisse pas cassée à 1 XP.
                            width: max(_xpBar.width * s * ratio, _xpBar.height * s),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6B93B),
                              borderRadius: BorderRadius.circular(4 * s),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              put(
                _avatar,
                Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F8F8C),
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.gold, width: max(3, 6 * s)),
                  ),
                  child: Text(
                    (known ? p.username.substring(0, 1) : '?').toUpperCase(),
                    style: titleStyle(26 * u, Palette.cream),
                  ),
                ),
              ),
              put(const Rect.fromLTWH(586, 40, 92, 80), Image.asset(Assets.coins, fit: BoxFit.contain)),
              put(const Rect.fromLTWH(688, 34, 140, 46), text(known ? '${p.talents}' : '–', 40, Colors.white)),
              put(const Rect.fromLTWH(688, 82, 140, 34), text('Talents', 25, Palette.gold)),
              put(_gear.deflate(8), const CustomPaint(painter: _GearPainter())),
              tap(_profileTap, onProfile),
              tap(
                _talentPill,
                () => onMessage(
                    'Les talents se gagnent en jouant, et 10 arrivent chaque jour avec le pain quotidien.'),
              ),
              tap(_gear, onProfile),
            ],
          ),
        );
      },
    );
  }
}

/// Badge du Rang S (les 10 premiers du classement général).
class RankSBadge extends StatelessWidget {
  final double side;

  const RankSBadge({super.key, required this.side});

  @override
  Widget build(BuildContext context) => Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF2C14E),
          borderRadius: BorderRadius.circular(side * 0.3),
          border: Border.all(color: const Color(0xFFFFE9A0), width: max(1, side * 0.1)),
          boxShadow: [BoxShadow(color: const Color(0x995A2E05), offset: Offset(0, side * 0.12))],
        ),
        child: Text('S', style: titleStyle(side * 0.7, const Color(0xFF5A2E06))),
      );
}

/// Roue des réglages dorée, dessinée.
class _GearPainter extends CustomPainter {
  static const _teeth = 8;

  const _GearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) / 2;
    final outer = r * 0.98;
    final inner = r * 0.74;
    final path = Path();
    for (var i = 0; i < _teeth * 4; i++) {
      final a = 2 * pi * i / (_teeth * 4) - pi / 2;
      final radius = (i % 4 == 1 || i % 4 == 2) ? outer : inner;
      final p = c + Offset(cos(a), sin(a)) * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    final gold = Paint()
      ..color = const Color(0xFFF2D58C)
      ..isAntiAlias = true;
    canvas.drawPath(path, gold);
    canvas.drawCircle(c, r * 0.62, gold);
    canvas.drawCircle(c, r * 0.3, Paint()..color = const Color(0xFF13275E));
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..color = const Color(0xFFC99A3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, r * 0.06),
    );
  }

  @override
  bool shouldRepaint(_GearPainter old) => false;
}
