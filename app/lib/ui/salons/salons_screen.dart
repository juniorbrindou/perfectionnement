import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/online.dart';
import '../../state/reglages.dart';
import '../../state/salons.dart';
import '../game/table.dart';
import '../theme.dart';
import '../toast.dart';
import 'salon_create_screen.dart';
import 'salon_page.dart';
import 'salon_theme.dart';

/// Pastille d'un salon : sa couleur et son initiale.
class SalonEmblem extends StatelessWidget {
  final String name;
  final int color;
  final double size;

  const SalonEmblem({super.key, required this.name, required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: salonColor(color),
      borderRadius: BorderRadius.circular(size * 0.3),
      border: Border.all(color: const Color(0x99FFE6B4), width: size * 0.045),
      boxShadow: [BoxShadow(color: const Color(0x55000000), blurRadius: size * 0.3, offset: Offset(0, size * 0.06))],
    ),
    child: Text(salonInitial(name), style: titleStyle(size * 0.48, Colors.white)),
  );
}

/// Initiale d'un salon, sans l'article : « Les Psalmistes » → P, « L'Arche » → A.
String salonInitial(String name) {
  final n = name.trim().replaceFirst(RegExp(r"^(?:(?:les|le|la|un|une|des|du)\s+|l['’]\s*)", caseSensitive: false), '');
  final s = n.isEmpty ? name.trim() : n;
  return s.isEmpty ? '?' : s.characters.first.toUpperCase();
}

/// Barre du haut des écrans de salon : retour et titre.
class SalonTopBar extends StatelessWidget {
  final SalonTheme theme;
  final String title;
  final String? subtitle;

  const SalonTopBar({super.key, required this.theme, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14 * k, 6 * k, 14 * k, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38 * k,
              height: 38 * k,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.dark ? const Color(0xBF2E1A33) : const Color(0xE6FFFDF4),
                border: Border.all(color: theme.accent.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Icon(Icons.chevron_left_rounded, color: theme.accent, size: 26 * k),
            ),
          ),
          SizedBox(width: 12 * k),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle(28 * k, theme.title).copyWith(
                    shadows: [
                      Shadow(color: theme.dark ? const Color(0x99000000) : const Color(0xE6FFFAEB), blurRadius: 10),
                    ],
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Garamond',
                      fontStyle: FontStyle.italic,
                      fontSize: 15 * k,
                      color: theme.dark ? const Color(0xFFF1CFA0) : theme.soft,
                      fontVariations: const [FontVariation('wght', 500)],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La liste de tous les salons, dans l'ambiance du repas de fête.
class SalonsScreen extends StatefulWidget {
  const SalonsScreen({super.key});

  @override
  State<SalonsScreen> createState() => _SalonsScreenState();
}

class _SalonsScreenState extends State<SalonsScreen> {
  static const _t = SalonTheme.fete;
  final _search = TextEditingController();
  Timer? _debounce;
  String? _difficulty;
  List<SalonInfo>? _salons;
  String _mine = '';
  String _request = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Salons.list(search: _search.text.trim(), difficulty: _difficulty);
      if (!mounted) return;
      setState(() {
        _salons = r.salons;
        _mine = r.mine;
        _request = r.request;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = Online.describe(e));
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _open(SalonInfo s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalonPage(id: s.id, preview: s),
      ),
    );
    _load();
  }

  Future<void> _create() async {
    if (_mine.isNotEmpty) {
      showToast(context, 'Tu es déjà membre d’un salon : quitte-le pour en créer un.');
      return;
    }
    final created = await Navigator.of(
      context,
    ).push<SalonInfo>(MaterialPageRoute(builder: (_) => const SalonCreateScreen()));
    await _load();
    if (created != null && mounted) _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final salons = _salons;
    return Scaffold(
      backgroundColor: _t.background,
      body: SalonBackdrop(
        theme: _t,
        headerHeight: 200 * k,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 70 * k),
              SalonTopBar(theme: _t, title: 'Les salons', subtitle: 'Choisis ta table'),
              Padding(
                padding: EdgeInsets.fromLTRB(16 * k, 10 * k, 16 * k, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchField(controller: _search, onChanged: _onSearch, theme: _t),
                    SizedBox(height: 10 * k),
                    Row(
                      children: [
                        for (final (value, label) in const [
                          (null, 'Tous'),
                          ('lait', 'Lait'),
                          ('manne', 'Manne'),
                          ('solide', 'Solide'),
                        ])
                          Padding(
                            padding: EdgeInsets.only(right: 6 * k),
                            child: _Chip(
                              label: label,
                              on: _difficulty == value,
                              theme: _t,
                              onTap: () {
                                setState(() => _difficulty = value);
                                _load();
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10 * k),
              Expanded(
                child: _error != null
                    ? _Message(text: _error!, theme: _t, onRetry: _load)
                    : salons == null
                    ? Center(child: CircularProgressIndicator(color: _t.accent))
                    : salons.isEmpty
                    ? _Message(
                        text: _search.text.isEmpty && _difficulty == null
                            ? 'Aucun salon pour l’instant. Crée le premier !'
                            : 'Aucun salon ne correspond.',
                        theme: _t,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: _t.accent,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(16 * k, 0, 16 * k, 16 * k),
                          itemCount: salons.length,
                          separatorBuilder: (_, _) => SizedBox(height: 9 * k),
                          itemBuilder: (_, i) => SalonCard(
                            salon: salons[i],
                            theme: _t,
                            mine: salons[i].id == _mine,
                            requested: salons[i].id == _request,
                            onTap: () => _open(salons[i]),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16 * k, 0, 16 * k, 14 * k),
                child: SalonButton(
                  'Créer un salon · ${Reglages.instance.salonCout} talents',
                  theme: _t,
                  onPressed: _create,
                  height: 52 * k,
                  fontSize: 19 * k,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SalonCard extends StatelessWidget {
  final SalonInfo salon;
  final SalonTheme theme;
  final bool mine;
  final bool requested;
  final VoidCallback onTap;

  const SalonCard({
    super.key,
    required this.salon,
    required this.theme,
    required this.onTap,
    this.mine = false,
    this.requested = false,
  });

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final t = theme;
    final status = mine
        ? 'Ton salon'
        : (requested ? 'Demande envoyée' : (salon.full ? 'Complet' : '${salon.members}/${salon.max}'));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13 * k, vertical: 11 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * k),
          gradient: t.dark ? const LinearGradient(colors: [Color(0x29FFD696), Color(0x0FFFD696)]) : null,
          color: t.dark ? null : t.card,
          border: Border.all(color: mine ? t.accent : t.cardEdge, width: mine ? 2 : 1),
          boxShadow: t.dark ? null : const [BoxShadow(color: Color(0x1F50592F), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            SalonEmblem(name: salon.name, color: salon.color, size: 44 * k),
            SizedBox(width: 12 * k),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    salon.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle(17 * k, t.dark ? t.text : t.title),
                  ),
                  SizedBox(height: 2 * k),
                  Text(
                    '${salon.difficultyLabel} · ${salon.contentLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle(11.5 * k, t.soft),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8 * k),
            Text(status, style: titleStyle(14 * k, t.dark ? const Color(0xFFFFD690) : t.accent)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final SalonTheme theme;

  const _SearchField({required this.controller, required this.onChanged, required this.theme});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Container(
      height: 42 * k,
      padding: EdgeInsets.symmetric(horizontal: 14 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21 * k),
        color: theme.dark ? const Color(0x1FFFF0D7) : Colors.white,
        border: Border.all(color: theme.accent.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20 * k, color: theme.soft),
          SizedBox(width: 8 * k),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: theme.accent,
              style: bodyStyle(15 * k, theme.text),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Chercher un salon',
                hintStyle: bodyStyle(15 * k, theme.soft),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final SalonTheme theme;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.on, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 5 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * k),
          color: on ? theme.accent : null,
          border: Border.all(color: theme.accent.withValues(alpha: on ? 1 : 0.5), width: 1.5),
        ),
        child: Text(label, style: bodyStyle(12 * k, on ? theme.background : theme.accent, weight: 900)),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final SalonTheme theme;
  final VoidCallback? onRetry;

  const _Message({required this.text, required this.theme, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28 * k),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: bodyStyle(15 * k, theme.text)),
            if (onRetry != null) ...[
              SizedBox(height: 14 * k),
              TextButton(
                onPressed: onRetry,
                child: Text('Réessayer', style: titleStyle(17 * k, theme.accent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
