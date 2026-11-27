import 'package:flutter/material.dart';

/// Couleurs et polices communes.
abstract final class Palette {
  static const cream = Color(0xFFFFFDF5);
  static const gold = Color(0xFFF6C24A);
  static const parchment = Color(0xFFFCDA9F);
  static const ink = Color(0xFF3A2412);
  static const night = Color(0xFF0E1F4C);
}

/// Texte courant (Nunito, police variable : la graisse passe par l'axe « wght »).
TextStyle bodyStyle(double size, Color color, {int weight = 800}) => TextStyle(
      fontFamily: 'Nunito',
      fontSize: size,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      height: 1.1,
    );

/// Titres (Lilita One).
TextStyle titleStyle(double size, Color color) =>
    TextStyle(fontFamily: 'Lilita', fontSize: size, color: color, height: 1.1);

/// Unité de mise en page : les tailles des maquettes sont données pour un écran de 390 de large.
double unit(BuildContext context) => MediaQuery.sizeOf(context).width / 390;
