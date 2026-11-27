import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Carte détruite par le feu doré, porté de scripts/ui/feu_dore.gd : la carte est
/// photographiée, puis la photo brûle de bas en haut (shaders/feu_dore.frag) ; des
/// étincelles montent du front de flamme, des cendres retombent et une lueur chaude suit
/// le front.
class FeuDore extends StatefulWidget {
  final Widget child;
  final Size size;

  /// Durée de la brûlure ; les dernières étincelles et cendres retombent ensuite.
  final Duration duration;

  /// La carte a fini de brûler.
  final VoidCallback? onConsumed;

  const FeuDore({
    super.key,
    required this.child,
    required this.size,
    this.duration = const Duration(milliseconds: 650),
    this.onConsumed,
  });

  @override
  State<FeuDore> createState() => _FeuDoreState();
}

class _Particle {
  Offset pos;
  Offset vel;
  double age = 0;
  final double life;
  final double size;
  double angle;
  final double spin;

  _Particle(this.pos, this.vel, this.life, this.size, {this.angle = 0, this.spin = 0});
}

class _FeuDoreState extends State<FeuDore> with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _program;
  static const _fadeOut = 0.7;

  final _boundary = GlobalKey();
  final _rng = Random();
  final _frame = ValueNotifier<int>(0);
  final List<_Particle> _sparks = [];
  final List<_Particle> _ash = [];
  late final Ticker _ticker = createTicker(_tick);
  late final double _seed = _rng.nextDouble() * 10;

  ui.FragmentShader? _shader;
  ui.Image? _photo;
  Duration _last = Duration.zero;
  double _t = 0;
  double _sparkDebt = 0;
  double _ashDebt = 0;
  bool _consumed = false;

  double get _duration => widget.duration.inMicroseconds / 1e6;
  double get _progress => (_t / _duration).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset('shaders/feu_dore.frag'));
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      final box = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (box == null) return;
      final photo = await box.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      if (!mounted) return;
      setState(() {
        _shader = program.fragmentShader();
        _photo = photo;
      });
      _ticker.start();
    } catch (e) {
      // Sans shader : la carte s'efface simplement.
      debugPrint('Feu doré indisponible : $e');
      if (mounted) {
        setState(() => _consumed = true);
        widget.onConsumed?.call();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _photo?.dispose();
    super.dispose();
  }

  /// Hauteur moyenne du front (voir le shader), depuis le haut de la carte.
  double _frontY(double p) {
    final front = p * 1.3 - 0.1;
    return (1 - (front - 0.17) / 0.78).clamp(0.0, 1.0) * widget.size.height;
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _t += dt;
    final w = widget.size.width, h = widget.size.height;
    final p = _progress;
    if (p < 1) {
      final y = _frontY(p);
      // Étincelles : ~120 par seconde, du front vers le haut.
      _sparkDebt += dt * 180;
      while (_sparkDebt >= 1) {
        _sparkDebt--;
        final a = -pi / 2 + (_rng.nextDouble() - 0.5) * 2 * (28 * pi / 180);
        final v = h * (1.2 + _rng.nextDouble() * 0.8); // plus vite que le front, qui monte vite
        _sparks.add(
          _Particle(
            Offset(w / 2 + (_rng.nextDouble() - 0.5) * w * 0.94, y + (_rng.nextDouble() - 0.5) * 10),
            Offset(cos(a), sin(a)) * v,
            0.55 * (0.6 + _rng.nextDouble() * 0.4),
            0.8 + _rng.nextDouble() * 1.3,
          ),
        );
      }
      // Cendres : quelques flocons sombres qui retombent en tournant.
      _ashDebt += dt * 16;
      while (_ashDebt >= 1) {
        _ashDebt--;
        final a = -pi / 2 + (_rng.nextDouble() - 0.5) * 2 * (70 * pi / 180);
        _ash.add(
          _Particle(
            Offset(w / 2 + (_rng.nextDouble() - 0.5) * w * 0.94, y),
            Offset(cos(a), sin(a)) * h * (0.03 + _rng.nextDouble() * 0.06),
            1.6 * (0.6 + _rng.nextDouble() * 0.4),
            2.5 + _rng.nextDouble() * 2.5,
            angle: _rng.nextDouble() * pi,
            spin: (_rng.nextDouble() - 0.5) * 2 * pi,
          ),
        );
      }
    } else if (!_consumed) {
      _consumed = true;
      widget.onConsumed?.call();
    }
    for (final s in _sparks) {
      s.age += dt;
      s.vel = s.vel * (1 - 1.2 * dt) + Offset(0, -h * 1.2 * dt);
      s.pos += s.vel * dt;
    }
    for (final a in _ash) {
      a.age += dt;
      a.vel = a.vel + Offset(0, h * 0.09 * dt);
      a.pos += a.vel * dt;
      a.angle += a.spin * dt;
    }
    _sparks.removeWhere((s) => s.age >= s.life);
    _ash.removeWhere((a) => a.age >= a.life);
    if (_t > _duration + _fadeOut && _sparks.isEmpty && _ash.isEmpty) _ticker.stop();
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo, shader = _shader;
    if (photo == null || shader == null) {
      return SizedBox.fromSize(
        size: widget.size,
        child: _consumed ? null : RepaintBoundary(key: _boundary, child: widget.child),
      );
    }
    return CustomPaint(size: widget.size, painter: _FirePainter(this, photo, shader));
  }
}

class _FirePainter extends CustomPainter {
  final _FeuDoreState s;
  final ui.Image photo;
  final ui.FragmentShader shader;

  _FirePainter(this.s, this.photo, this.shader) : super(repaint: s._frame);

  @override
  void paint(Canvas canvas, Size size) {
    final p = s._progress;
    if (p < 1) {
      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, p)
        ..setFloat(3, s._seed)
        ..setImageSampler(0, photo);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);

      // Lueur chaude qui suit le front.
      final flicker = 0.55 + 0.15 * sin(s._t * 23);
      final fade = (1 - _smooth(0.85, 1, p)) * _smooth(0, 0.08, p);
      final y = s._frontY(p);
      final light = Rect.fromCenter(
        center: Offset(size.width / 2, y),
        width: size.width * 1.5,
        height: size.width * 0.55,
      );
      canvas.drawOval(
        light,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [Color.fromRGBO(255, 140, 38, flicker * fade), const Color.fromRGBO(255, 140, 38, 0)],
          ).createShader(light),
      );
    }

    for (final a in s._ash) {
      final k = a.age / a.life;
      final color = Color.lerp(const Color(0xE6332115), const Color(0x00595250), k)!;
      canvas.save();
      canvas.translate(a.pos.dx, a.pos.dy);
      canvas.rotate(a.angle);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: a.size, height: a.size * 0.7),
        Paint()..color = color,
      );
      canvas.restore();
    }

    final glow = Paint()..blendMode = BlendMode.plus;
    for (final sp in s._sparks) {
      final k = sp.age / sp.life;
      final color = k < 0.45
          ? Color.lerp(const Color(0xFFFFF7BF), const Color(0xE6FF9E26), k / 0.45)!
          : Color.lerp(const Color(0xE6FF9E26), const Color(0x00E6400D), (k - 0.45) / 0.55)!;
      final r = sp.size * (1 - 0.4 * k);
      canvas.drawCircle(
        sp.pos,
        r * 2.6,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = color.withValues(alpha: color.a * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.6),
      );
      canvas.drawCircle(sp.pos, r, glow..color = color);
    }
  }

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(_FirePainter old) => old.photo != photo;
}
