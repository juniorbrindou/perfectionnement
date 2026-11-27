import 'package:flutter/material.dart';

import 'theme.dart';

/// Bulle de message au milieu de l'écran, qui s'efface seule.
void showToast(BuildContext context, String text) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Toast(text, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String text;
  final VoidCallback onDone;

  const _Toast(this.text, {required this.onDone});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) _fade.forward().whenComplete(widget.onDone);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = unit(context);
    final width = MediaQuery.sizeOf(context).width;
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: ReverseAnimation(_fade),
          child: Container(
            width: width * 0.84,
            padding: EdgeInsets.symmetric(horizontal: 18 * u, vertical: 12 * u),
            decoration: BoxDecoration(
              color: const Color(0xF0141A33),
              borderRadius: BorderRadius.circular(18 * u),
              border: Border.all(color: const Color(0xFFF6C24A), width: 2 * u),
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: bodyStyle(16 * u, Palette.cream).copyWith(decoration: TextDecoration.none),
            ),
          ),
        ),
      ),
    );
  }
}
