import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Nuages qui dérivent lentement dans le ciel ajouté au-dessus de l'image d'accueil.
class SkyClouds extends StatefulWidget {
  const SkyClouds({super.key});

  @override
  State<SkyClouds> createState() => _SkyCloudsState();
}

class _SkyCloudsState extends State<SkyClouds> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CloudsPainter(_time), size: Size.infinite);
}

class _CloudsPainter extends CustomPainter {
  static const _puffs = [Offset(0, 0), Offset(0.9, -0.35), Offset(1.8, -0.1), Offset(2.5, 0.15), Offset(1.2, 0.25)];
  static const _radii = [0.8, 1.0, 0.9, 0.6, 0.85];

  /// Position de départ (fraction de largeur, fraction de hauteur), taille, vitesse (px/s).
  static const _clouds = [(0.15, 0.35, 22.0, 6.0), (0.62, 0.6, 30.0, 9.0), (0.9, 0.22, 16.0, 4.5)];

  final ValueNotifier<double> time;

  _CloudsPainter(this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height < 20) return;
    final w = size.width;
    final shade = Paint()..color = const Color(0x73C7DBFF);
    final white = Paint()..color = const Color(0xD9FFFFFF);
    for (final (fx, fy, radius, speed) in _clouds) {
      final r = radius * w / 390;
      final span = w + r * 6;
      final x = (fx * w + time.value * speed) % span - r * 3;
      final y = fy * size.height;
      for (var i = 0; i < _puffs.length; i++) {
        final p = _puffs[i];
        canvas.drawCircle(Offset(x + p.dx * r, y + p.dy * r + r * 0.12), _radii[i] * r, shade);
      }
      for (var i = 0; i < _puffs.length; i++) {
        final p = _puffs[i];
        canvas.drawCircle(Offset(x + p.dx * r, y + p.dy * r), _radii[i] * r, white);
      }
    }
  }

  @override
  bool shouldRepaint(_CloudsPainter old) => false;
}
