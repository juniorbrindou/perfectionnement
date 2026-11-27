import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// La fête de la victoire : canons à confettis dans les coins du bas, feux d'artifice dans le
/// ciel, puis une pluie de confettis qui s'apaise. Se pose par-dessus l'écran sans gêner les
/// touchers.
class Celebration extends StatefulWidget {
  const Celebration({super.key});

  @override
  State<Celebration> createState() => _CelebrationState();
}

const _confettiColors = [
  Color(0xFFF6C24A),
  Color(0xFFFFE9A8),
  Color(0xFFFFFDF5),
  Color(0xFF1FA9A3),
  Color(0xFF3A6FD8),
  Color(0xFFE5566B),
  Color(0xFF6CC56F),
  Color(0xFFFF9A2A),
];
const _fireColors = [
  [Color(0xFFFFF3C4), Color(0xFFF6C24A)],
  [Color(0xFFFFE0B0), Color(0xFFFF8A2A)],
  [Color(0xFFD8FFF8), Color(0xFF1FA9A3)],
  [Color(0xFFFFD6E0), Color(0xFFE5566B)],
  [Color(0xFFE2ECFF), Color(0xFF6E9BFF)],
];

class _Confetto {
  Offset pos, vel;
  double angle, spin, flip, flipSpeed;
  final double w, h;
  final Color color;
  double age = 0;
  final double life;

  _Confetto(
    this.pos,
    this.vel,
    this.angle,
    this.spin,
    this.flip,
    this.flipSpeed,
    this.w,
    this.h,
    this.color,
    this.life,
  );
}

class _Spark {
  Offset pos, vel;
  double age = 0;
  final double life;
  final Color core, glow;
  final double size;

  _Spark(this.pos, this.vel, this.life, this.core, this.glow, this.size);
}

class _Rocket {
  Offset pos;
  final Offset vel;
  final double burstY;
  final int colors;

  _Rocket(this.pos, this.vel, this.burstY, this.colors);
}

class _CelebrationState extends State<Celebration> with SingleTickerProviderStateMixin {
  final _rng = Random();
  final _frame = ValueNotifier<int>(0);
  final List<_Confetto> _confetti = [];
  final List<_Spark> _sparks = [];
  final List<_Rocket> _rockets = [];
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;
  double _nextRocket = 0.35;
  double _rainDebt = 0;
  bool _cannons = false;
  Size _size = Size.zero;

  double _r(double a, double b) => a + _rng.nextDouble() * (b - a);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _fireCannons() {
    final s = _size;
    for (final left in [true, false]) {
      for (var i = 0; i < 70; i++) {
        final a = left ? _r(-1.35, -0.75) : _r(-pi + 0.75, -pi + 1.35);
        final v = s.height * _r(0.9, 1.6);
        _confetti.add(
          _newConfetto(Offset(left ? -10 : s.width + 10, s.height * 0.92), Offset(cos(a), sin(a)) * v, _r(3.2, 4.6)),
        );
      }
    }
  }

  _Confetto _newConfetto(Offset pos, Offset vel, double life) => _Confetto(
    pos,
    vel,
    _r(0, pi),
    _r(-6, 6),
    _r(0, pi),
    _r(6, 14),
    _r(5, 8),
    _r(9, 14),
    _confettiColors[_rng.nextInt(_confettiColors.length)],
    life,
  );

  void _launch() {
    final s = _size;
    _rockets.add(
      _Rocket(
        Offset(_r(0.15, 0.85) * s.width, s.height + 10),
        Offset(_r(-30, 30), -s.height * _r(1.05, 1.3)),
        s.height * _r(0.1, 0.38),
        _rng.nextInt(_fireColors.length),
      ),
    );
  }

  void _burst(_Rocket r) {
    final c = _fireColors[r.colors];
    final n = 46 + _rng.nextInt(20);
    final speed = _size.width * _r(0.42, 0.6);
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * pi + _r(-0.05, 0.05);
      final v = speed * _r(0.75, 1.0);
      _sparks.add(_Spark(r.pos, Offset(cos(a), sin(a)) * v, _r(0.9, 1.4), c[0], c[1], _r(1.6, 2.6)));
    }
    // Un éclat blanc au centre.
    _sparks.add(_Spark(r.pos, Offset.zero, 0.25, Colors.white, c[1], 18));
  }

  void _tick(Duration elapsed) {
    if (_size == Size.zero) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _t += dt;
    final s = _size;

    if (!_cannons && _t > 0.15) {
      _cannons = true;
      _fireCannons();
    }
    // Feux d'artifice nourris au début, puis de temps en temps.
    if (_t >= _nextRocket && _t < 12) {
      _launch();
      if (_t < 3 && _rng.nextBool()) _launch();
      _nextRocket = _t + (_t < 3 ? _r(0.35, 0.6) : _r(0.9, 1.6));
    }
    // Pluie de confettis qui s'apaise.
    final rain = _t < 1 ? 0.0 : (_t < 5 ? 40.0 : (_t < 12 ? 8.0 : 0.0));
    _rainDebt += dt * rain;
    while (_rainDebt >= 1) {
      _rainDebt--;
      _confetti.add(_newConfetto(Offset(_r(0, s.width), -20), Offset(_r(-30, 30), _r(40, 120)), _r(4, 6)));
    }

    for (final r in _rockets) {
      r.pos += (r.vel + Offset(sin(_t * 30) * 8, 0)) * dt;
    }
    for (final r in _rockets.where((r) => r.pos.dy <= r.burstY).toList()) {
      _burst(r);
      _rockets.remove(r);
    }
    for (final sp in _sparks) {
      sp.age += dt;
      sp.vel = sp.vel * (1 - 1.6 * dt) + Offset(0, s.height * 0.18 * dt);
      sp.pos += sp.vel * dt;
    }
    for (final c in _confetti) {
      c.age += dt;
      c.vel = c.vel * (1 - 1.4 * dt) + Offset(0, s.height * 0.55 * dt);
      // Les confettis flottent : leur chute est freinée et ils dérivent.
      if (c.vel.dy > s.height * 0.22) c.vel = Offset(c.vel.dx, s.height * 0.22);
      c.pos += (c.vel + Offset(sin(c.age * 3 + c.flip) * 25, 0)) * dt;
      c.angle += c.spin * dt;
      c.flip += c.flipSpeed * dt;
    }
    _sparks.removeWhere((p) => p.age >= p.life);
    _confetti.removeWhere((c) => c.age >= c.life || c.pos.dy > s.height + 30);
    if (_t > 12 && _sparks.isEmpty && _confetti.isEmpty && _rockets.isEmpty) _ticker.stop();
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, c) {
        _size = c.biggest;
        return CustomPaint(size: c.biggest, painter: _PartyPainter(this));
      },
    ),
  );
}

class _PartyPainter extends CustomPainter {
  final _CelebrationState s;

  _PartyPainter(this.s) : super(repaint: s._frame);

  @override
  void paint(Canvas canvas, Size size) {
    final add = Paint()..blendMode = BlendMode.plus;
    for (final r in s._rockets) {
      canvas.drawCircle(r.pos, 2.4, add..color = const Color(0xFFFFF1C0));
      canvas.drawLine(
        r.pos,
        r.pos - r.vel * 0.05,
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: const [Color(0xCCFFD37A), Color(0x00FFD37A)],
          ).createShader(Rect.fromPoints(r.pos, r.pos - r.vel * 0.05)),
      );
    }
    for (final p in s._sparks) {
      final k = p.age / p.life;
      final a = (1 - k) * (1 - k);
      // Petite traînée dans le sens du mouvement.
      canvas.drawLine(
        p.pos,
        p.pos - p.vel * 0.035,
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeWidth = p.size
          ..strokeCap = StrokeCap.round
          ..color = p.glow.withValues(alpha: 0.55 * a),
      );
      canvas.drawCircle(p.pos, p.size * (p.size > 10 ? 1 - k : 1), add..color = p.core.withValues(alpha: a));
    }
    final paint = Paint();
    for (final c in s._confetti) {
      final fade = c.age > c.life - 0.6 ? (c.life - c.age) / 0.6 : 1.0;
      canvas.save();
      canvas.translate(c.pos.dx, c.pos.dy);
      canvas.rotate(c.angle);
      canvas.scale(cos(c.flip), 1); // il tourne sur lui-même
      final shade = 0.75 + 0.25 * sin(c.flip).abs();
      paint.color = Color.lerp(Colors.black, c.color, shade)!.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: c.w, height: c.h),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PartyPainter old) => false;
}

/// Rayons dorés qui tournent lentement derrière le gagnant.
class GloryRays extends StatefulWidget {
  final double size;

  const GloryRays({super.key, required this.size});

  @override
  State<GloryRays> createState() => _GloryRaysState();
}

class _GloryRaysState extends State<GloryRays> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RotationTransition(
      turns: _c,
      child: CustomPaint(size: Size.square(widget.size), painter: _RaysPainter()),
    ),
  );
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rays = Path();
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a0 = i / n * 2 * pi, a1 = a0 + pi / n * 0.55;
      rays
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a0) * r, c.dy + sin(a0) * r)
        ..lineTo(c.dx + cos(a1) * r, c.dy + sin(a1) * r)
        ..close();
    }
    canvas.drawPath(
      rays,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x88FFE39A), Color(0x33F6C24A), Color(0x00F6C24A)],
          stops: const [0.15, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.45,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x66FFE39A), Color(0x00FFE39A)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.45)),
    );
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}
