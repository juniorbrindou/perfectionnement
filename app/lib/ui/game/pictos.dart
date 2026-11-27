import 'package:flutter/material.dart';

/// Pictos des cartes (docs/maquettes/carte.html), dessinés dans une grille de 24 × 24.
enum Picto { lait, manne, solide, personnages, miracles, paraboles, lieuxEvenements, ok, non }

Picto pictoForDifficulty(String d) => switch (d) {
  'manne' => Picto.manne,
  'solide' => Picto.solide,
  _ => Picto.lait,
};

Picto pictoForCategory(String c) => switch (c) {
  'miracles' => Picto.miracles,
  'paraboles' => Picto.paraboles,
  'lieux_evenements' => Picto.lieuxEvenements,
  _ => Picto.personnages,
};

class PictoIcon extends StatelessWidget {
  final Picto picto;
  final double size;
  final Color color;
  final double stroke;

  const PictoIcon(this.picto, {super.key, required this.size, this.color = const Color(0xFFF3EAD6), this.stroke = 1.6});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _PictoPainter(picto, color, stroke));
}

class _PictoPainter extends CustomPainter {
  final Picto picto;
  final Color color;
  final double stroke;

  _PictoPainter(this.picto, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    switch (picto) {
      case Picto.lait:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..cubicTo(12, 3, 6.5, 10, 6.5, 14)
            ..arcToPoint(const Offset(17.5, 14), radius: const Radius.circular(5.5), clockwise: false)
            ..cubicTo(17.5, 10, 12, 3, 12, 3)
            ..close(),
          fill,
        );
      case Picto.manne:
        for (final (x, y, rx, ry) in const [
          (8.0, 9.0, 2.6, 2.2),
          (15.5, 7.5, 2.3, 2.0),
          (12.0, 14.0, 2.8, 2.4),
          (6.5, 16.5, 2.0, 1.8),
          (17.5, 15.0, 2.2, 1.9),
        ]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), fill);
        }
      case Picto.solide:
        canvas.drawPath(
          Path()
            ..moveTo(4, 15.5)
            ..cubicTo(3, 9, 8, 6.5, 12, 6.5)
            ..cubicTo(16, 6.5, 21, 9, 20, 15.5)
            ..cubicTo(19.7, 17.3, 18.5, 18, 17, 18)
            ..lineTo(7, 18)
            ..cubicTo(5.5, 18, 4.3, 17.3, 4, 15.5)
            ..close(),
          fill,
        );
        final cuts = Paint()
          ..color = const Color(0xFF13234A)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(9, 9.5), const Offset(7.7, 12.5), cuts);
        canvas.drawLine(const Offset(12.5, 9), const Offset(11.2, 12.2), cuts);
        canvas.drawLine(const Offset(16, 9.5), const Offset(14.7, 12.5), cuts);
      case Picto.personnages:
        canvas.drawCircle(const Offset(12, 8.5), 3.8, line);
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 20.5)
            ..cubicTo(4.5, 16.2, 7.9, 13.5, 12, 13.5)
            ..cubicTo(16.1, 13.5, 19.5, 16.2, 19.5, 20.5),
          line,
        );
      case Picto.miracles:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..cubicTo(12.6, 8.5, 15.5, 11.4, 21, 12)
            ..cubicTo(15.5, 12.6, 12.6, 15.5, 12, 21)
            ..cubicTo(11.4, 15.5, 8.5, 12.6, 3, 12)
            ..cubicTo(8.5, 11.4, 11.4, 8.5, 12, 3)
            ..close(),
          line,
        );
        canvas.drawLine(const Offset(18.5, 3.5), const Offset(18.5, 6.5), line);
        canvas.drawLine(const Offset(17, 5), const Offset(20, 5), line);
      case Picto.paraboles:
        canvas.drawLine(const Offset(12, 21), const Offset(12, 11), line);
        canvas.drawPath(
          Path()
            ..moveTo(12, 13)
            ..cubicTo(12, 8.5, 8.5, 6, 4.5, 6.5)
            ..cubicTo(4.5, 10.5, 7.5, 13, 12, 13)
            ..close()
            ..moveTo(12, 11)
            ..cubicTo(12, 6.5, 15, 4, 19.5, 4)
            ..cubicTo(19.5, 8, 16.5, 11, 12, 11)
            ..close(),
          line,
        );
      case Picto.lieuxEvenements:
        canvas.drawPath(
          Path()
            ..moveTo(12, 21)
            ..cubicTo(12, 21, 5.5, 14.5, 5.5, 9.5)
            ..arcToPoint(const Offset(18.5, 9.5), radius: const Radius.circular(6.5))
            ..cubicTo(18.5, 14.5, 12, 21, 12, 21)
            ..close(),
          line,
        );
        canvas.drawCircle(const Offset(12, 9.5), 2.4, line);
      case Picto.ok:
        canvas.drawPath(
          Path()
            ..moveTo(5, 12.5)
            ..lineTo(9.5, 17)
            ..lineTo(19, 7.5),
          line,
        );
      case Picto.non:
        canvas.drawLine(const Offset(6.5, 6.5), const Offset(17.5, 17.5), line);
        canvas.drawLine(const Offset(17.5, 6.5), const Offset(6.5, 17.5), line);
    }
  }

  @override
  bool shouldRepaint(_PictoPainter old) => old.picto != picto || old.color != color || old.stroke != stroke;
}
