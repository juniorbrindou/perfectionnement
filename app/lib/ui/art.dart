import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Chemins des images et données, partagées avec la version Godot pendant la réécriture.
abstract final class Assets {
  static const home = 'assets/accueil/accueil.png';
  static const coins = 'assets/duel/pieces.png';
  static const crown = 'assets/duel/couronne.png';
  static const adventure = 'data/aventure.json';
}

/// Image décodée une fois, pour en dessiner des morceaux.
Future<ui.Image> loadImage(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

/// Un rectangle d'une image, étiré sur la place donnée.
class Crop extends StatelessWidget {
  final ui.Image image;
  final Rect region;

  const Crop(this.image, this.region, {super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CropPainter(image, region), size: Size.infinite);
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect region;

  _CropPainter(this.image, this.region);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      region,
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.image != image || old.region != region;
}
