import 'dart:math';

import 'package:flutter/material.dart';

import '../state/sound.dart';

/// Animation de démarrage « Le duel s'ouvre » (docs/SPLASH.md), portée de scripts/ui/splash.gd :
/// mêmes instants et mêmes courbes que la maquette validée. Un toucher la passe. Elle recouvre
/// l'accueil, qui se charge dessous, et dépose le logo à la place de son titre.
class Splash extends StatefulWidget {
  /// Jouée une seule fois, au lancement à froid.
  static bool shown = false;

  static const endMs = 3060.0;

  /// Rectangle du titre dans l'image d'accueil (941 × 1672).
  static const homeTitle = Rect.fromLTWH(84, 115, 784, 410);

  final VoidCallback onDone;

  const Splash({super.key, required this.onDone});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  static const _cues = {300: 'carte', 790: 'feu', 1300: 'juste'};

  late final AnimationController _clock =
      AnimationController(vsync: this, duration: Duration(milliseconds: Splash.endMs.toInt()));
  final Set<int> _played = {};
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Sound.instance.beginIntro();
    _clock.addListener(_sounds);
    _clock.forward().whenComplete(_finish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final a in const ['assets/logo/logo_livre.png', 'assets/logo/logo_enseigne.png', 'assets/duel/dos_carte.png']) {
      precacheImage(AssetImage(a), context);
    }
  }

  void _sounds() {
    final t = _clock.value * Splash.endMs;
    _cues.forEach((at, effect) {
      if (t >= at && _played.add(at)) Sound.instance.play(effect, volume: 0.7);
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    Sound.instance.endIntro();
    widget.onDone();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: AnimatedBuilder(animation: _clock, builder: (context, _) => _frame(context, _clock.value * Splash.endMs)),
      );

  static double _progress(double t, double delay, double duration) => ((t - delay) / duration).clamp(0.0, 1.0);

  /// Interpolation entre images clés (décalage, valeur), comme en CSS.
  static double _keys(double p, List<(double, double)> frames) {
    for (var i = 1; i < frames.length; i++) {
      if (p <= frames[i].$1) {
        final (a, b) = (frames[i - 1], frames[i]);
        return a.$2 + (b.$2 - a.$2) * (p - a.$1) / max(b.$1 - a.$1, 0.0001);
      }
    }
    return frames.last.$2;
  }

  static double _curve(double x1, double y1, double x2, double y2, double p) =>
      p <= 0 || p >= 1 ? p : Cubic(x1, y1, x2, y2).transform(p);

  Widget _frame(BuildContext context, double t) {
    final size = MediaQuery.sizeOf(context);
    final k = size.width / 375;
    final center = Offset(size.width / 2, size.height * 0.46);

    // Place du titre sur l'accueil (même calcul que HomeScreen).
    final s = size.width / 941;
    final top = max(size.height - MediaQuery.viewPaddingOf(context).bottom - 1672 * s, 0.0);
    final to = Rect.fromLTWH(Splash.homeTitle.left * s, top + Splash.homeTitle.top * s,
        Splash.homeTitle.width * s, Splash.homeTitle.height * s);
    final from = Rect.fromLTWH(center.dx - 182 * k, center.dy - 96 * k, 365 * k, 191 * k);

    // Les deux cartes se rencontrent, puis se retournent dans la lumière.
    final cp = _curve(0.2, 0.8, 0.3, 1.0, _progress(t, 280, 520));
    var x = 330 + (34 - 330) * cp;
    final rot = 30 + (8 - 30) * cp;
    var alpha = _keys(cp, const [(0, 0), (0.3, 1), (1, 1)]);
    var flip = 0.0;
    if (t >= 860) {
      final q = _curve(0.42, 0.0, 1.0, 1.0, _progress(t, 860, 300));
      x = 34 + (10 - 34) * q;
      flip = q * pi / 2;
      alpha = 1 - q;
    }

    // Le choc : éclair et secousse.
    final fp = _curve(0.0, 0.0, 0.58, 1.0, _progress(t, 790, 600));
    final flash = t >= 790 ? _keys(fp, const [(0, 0), (0.35, 1), (1, 0)]) : 0.0;
    final flashScale = _keys(fp, const [(0, 0.5), (0.35, 9), (1, 14)]);
    final sp = _progress(t, 800, 260);
    final shake = sp > 0 && sp < 1
        ? Offset(_keys(sp, const [(0, 0), (0.25, -5), (0.5, 4), (0.75, -2), (1, 0)]),
                _keys(sp, const [(0, 0), (0.25, 3), (0.5, -3), (0.75, 1), (1, 0)])) *
            k
        : Offset.zero;

    // La colonne de lumière dorée.
    final col = _progress(t, 850, 900);
    final colAlpha = t >= 850 ? _keys(col, const [(0, 0), (0.4, 1), (1, 0)]) : 0.0;
    final colWidth = _keys(col, const [(0, 0.2), (0.4, 1), (1, 1.4)]);

    // La Bible s'élève, puis l'enseigne apparaît avec un rebond ; le reflet balaie les lettres.
    final fade = 1 - _progress(t, 2840, 220);
    final lp = _curve(0.2, 0.8, 0.3, 1.0, _progress(t, 920, 520));
    final bookY = _keys(lp, const [(0, 60), (0.7, -6), (1, 0)]) * k;
    final bookX = _keys(lp, const [(0, 0.35), (0.7, 1.06), (1, 1)]);
    final bookH = _keys(lp, const [(0, 0.2), (0.7, 1.06), (1, 1)]);
    final bookAlpha = (_keys(lp, const [(0, 0), (0.7, 1), (1, 1)]) * fade).clamp(0.0, 1.0);
    final ep = t >= 1280 ? Cubic(0.3, 1.2, 0.5, 1.0).transform(_progress(t, 1280, 480)) : 0.0;
    final signScale = _keys(ep, const [(0, 1.16), (0.7, 0.97), (1, 1)]);
    final signAlpha = (_keys(ep, const [(0, 0), (0.35, 1), (1, 1)]) * fade).clamp(0.0, 1.0);
    final shine = _curve(0.42, 0.0, 0.58, 1.0, _progress(t, 1780, 520));

    // Le logo monte jusqu'au titre de l'accueil, qui apparaît dessous.
    final mp = _curve(0.5, 0.0, 0.2, 1.0, _progress(t, 2280, 560));
    final logo = Rect.lerp(from, to, mp)!;
    final backdrop = 1 - _curve(0.42, 0.0, 1.0, 1.0, _progress(t, 2620, 380));

    Widget sign() => Image.asset('assets/logo/logo_enseigne.png', fit: BoxFit.fill);

    return Transform.translate(
      offset: shake,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: backdrop.clamp(0.0, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.08),
                    radius: 1.3,
                    colors: [Color(0xFF0D2A6B), Color(0xFF071B48), Color(0xFF03102A)],
                    stops: [0.0, 0.45, 0.85],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: Opacity(opacity: backdrop.clamp(0.0, 1.0), child: CustomPaint(painter: _Dust(t, k)))),
          if (colAlpha > 0)
            Positioned(
              left: center.dx - 80 * k * colWidth,
              width: 160 * k * colWidth,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: colAlpha.clamp(0.0, 1.0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0x00FFDB82), Color(0x8CFFE6A0), Color(0x00FFDB82)]),
                  ),
                ),
              ),
            ),
          if (t < 1200 && alpha > 0)
            for (final side in const [-1.0, 1.0])
              Positioned(
                left: center.dx - 56 * k + side * x * k,
                top: center.dy - 66 * k,
                width: 112 * k,
                height: 133 * k,
                child: Opacity(
                  opacity: alpha.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: side * rot * pi / 180,
                    child: Transform.scale(
                      scaleX: max(cos(flip), 0.001),
                      child: Image.asset('assets/duel/dos_carte.png', fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
          if (flash > 0)
            Positioned(
              left: center.dx - 15 * k * flashScale,
              top: center.dy - 15 * k * flashScale,
              width: 30 * k * flashScale,
              height: 30 * k * flashScale,
              child: Opacity(
                opacity: flash.clamp(0.0, 1.0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xFFFFFBE6), Color(0xFFFFD36A), Color(0x00FFB33D)],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(child: CustomPaint(painter: _Sparks(t, k, center))),
          Positioned.fromRect(
            rect: logo,
            child: Opacity(
              opacity: bookAlpha,
              child: Transform.translate(
                offset: Offset(0, bookY),
                child: Transform(
                  alignment: const Alignment(0.02, -0.44),
                  transform: Matrix4.diagonal3Values(bookX, bookH, 1),
                  child: Image.asset('assets/logo/logo_livre.png', fit: BoxFit.fill),
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: logo,
            child: Opacity(
              opacity: signAlpha,
              child: Transform.scale(
                scale: signScale,
                alignment: const Alignment(0, 0.24),
                child: t >= 1780 && t <= 2300
                    ? ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (rect) {
                          final c = -0.3 + 1.6 * shine;
                          return LinearGradient(
                            begin: const Alignment(-1, -0.27),
                            end: const Alignment(1, 0.27),
                            colors: const [Color(0x00FFFFFF), Color(0xD9FFFADC), Color(0x00FFFFFF)],
                            stops: [(c - 0.1).clamp(0.0, 1.0), c.clamp(0.0, 1.0), (c + 0.1).clamp(0.0, 1.0)],
                          ).createShader(rect);
                        },
                        child: sign(),
                      )
                    : sign(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 70 grains d'or qui scintillent et dérivent vers le haut (même tirage que la maquette).
class _Dust extends CustomPainter {
  final double t;
  final double k;

  _Dust(this.t, this.k);

  @override
  void paint(Canvas canvas, Size size) {
    var seed = 7;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    for (var i = 0; i < 70; i++) {
      final s = 1 + rnd() * 2.6;
      final at = Offset(rnd() * 375, 120 + rnd() * 580);
      final drift = Offset((rnd() - 0.5) * 30, -10 - rnd() * 30);
      final p = _SplashState._progress(t, rnd() * 300, 3200);
      final a = _SplashState._keys(p, const [(0, 0), (0.3, 0.9), (0.7, 0.2), (1, 0.8)]).clamp(0.0, 1.0);
      final c = (at + drift * p) * k;
      final r = s * 0.5 * k;
      canvas.drawCircle(c, r * 2.6, Paint()..color = Color.fromRGBO(255, 199, 89, 0.18 * a));
      canvas.drawCircle(c, r, Paint()..color = Color.fromRGBO(255, 214, 122, a));
    }
  }

  @override
  bool shouldRepaint(_Dust old) => old.t != t;
}

/// Les 18 étincelles du choc, qui partent en étoile.
class _Sparks extends CustomPainter {
  final double t;
  final double k;
  final Offset center;

  _Sparks(this.t, this.k, this.center);

  @override
  void paint(Canvas canvas, Size size) {
    if (t < 800 || t > 1320) return;
    final p = _SplashState._curve(0.1, 0.7, 0.3, 1.0, _SplashState._progress(t, 800, 520));
    var seed = 11;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    for (var i = 0; i < 18; i++) {
      final angle = ((i / 18) * 360 + rnd() * 12) * pi / 180;
      final distance = 90 + rnd() * 90;
      final dir = Offset(sin(angle), -cos(angle));
      final length = 14 * (1 - 0.6 * p) * k;
      final at = center + dir * distance * p * k;
      canvas.drawLine(
        at,
        at + dir * length,
        Paint()
          ..color = Color.fromRGBO(255, 214, 122, 1 - p)
          ..strokeWidth = 3 * k
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_Sparks old) => old.t != t;
}
