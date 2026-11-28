import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/adventure.dart';
import '../../state/arcade_match.dart';
import '../../state/online.dart';
import '../../state/player.dart';
import '../../state/reglages.dart';
import '../../state/session.dart';
import '../game/table.dart';
import '../online/duel_match_screen.dart';
import '../online/online_screen.dart';
import '../theme.dart';
import '../toast.dart';
import '../profile/profile_screen.dart';

/// L'aventure contre le Scribe (docs/maquettes/aventure.html, piste C « le livre du chapitre ») :
/// les niveaux du chapitre en petites cartes, puis le panneau du niveau choisi avec ses trois
/// difficultés et « Jouer ».
class AdventureScreen extends StatefulWidget {
  const AdventureScreen({super.key});

  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

class _Chapter {
  final String name;
  final List<String> books;
  final List<(int, String)> levels;

  _Chapter(this.name, this.books, this.levels);
}

class _AdventureScreenState extends State<AdventureScreen> {
  List<_Chapter> _chapters = const [];
  int _selected = -1;
  String _difficulty = 'lait';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await rootBundle.loadString('data/aventure.json');
    final chapters = [
      for (final c in ((jsonDecode(text) as Map)['chapitres'] as List? ?? const []))
        _Chapter(
          '${c['nom']}',
          [for (final b in (c['livres'] as List? ?? const [])) '$b'],
          [for (final n in (c['niveaux'] as List? ?? const [])) ((n['id'] as num).toInt(), '${n['nom']}')],
        ),
    ];
    if (!mounted) return;
    setState(() => _chapters = chapters);
    _select(Adventure.currentLevel(Player.instance.adventureStars, _levelCount));
    // Progression à jour depuis le serveur.
    try {
      final r = await Online.instance.rpc('arcade', {'action': 'etat'});
      final stars = (r['etoiles'] as Map?)?.map((k, v) => MapEntry('$k', v as List)) ?? const <String, List>{};
      await Online.instance.setAdventureStars(stars);
      if (!mounted) return;
      _select(Adventure.currentLevel(stars, _levelCount));
    } catch (_) {
      // Hors ligne : la carte s'affiche avec la progression gardée.
    }
  }

  int get _levelCount => _chapters.fold(0, (n, c) => n + c.levels.length);

  Map<String, List> get _stars => Player.instance.adventureStars;

  void _select(int level) {
    setState(() {
      _selected = level;
      final won = _stars['$level'] ?? const [];
      // Première difficulté pas encore gagnée.
      _difficulty = const ['lait', 'manne', 'solide'].firstWhere((d) => !won.contains(d), orElse: () => 'lait');
    });
  }

  /// L'Aventure demande un compte (PRD §3.1) : on propose de le créer au lieu de refuser.
  Future<void> _askAccount() async {
    final create = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Crée ton compte'),
        content: const Text('L’Aventure demande un compte. Ton pseudo, tes talents et ton niveau sont conservés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Plus tard')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Créer mon compte')),
        ],
      ),
    );
    if (create != true || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    if (_busy || _selected < 1) return;
    if (!Online.instance.isOnline) {
      showToast(context, 'L’aventure se joue en ligne : vérifie ta connexion.');
      return;
    }
    if (!Online.instance.hasAccount) {
      await _askAccount();
      return;
    }
    final stake = Reglages.instance.miseArcade(_difficulty);
    if (Player.instance.talents < stake) {
      showToast(context, 'Il te faut $stake talents pour cette difficulté.');
      return;
    }
    setState(() => _busy = true);
    final match = ArcadeMatch(_selected, _difficulty);
    final error = await match.start();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showToast(context, error);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DuelMatchScreen(source: match)));
    match.dispose();
    if (mounted) _select(Adventure.currentLevel(_stars, _levelCount));
  }

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Scaffold(
      backgroundColor: Palette.night,
      body: NightSky(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Player.instance,
            builder: (context, _) => Column(
              children: [
                _topBar(k),
                Expanded(
                  child: _chapters.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Palette.gold))
                      : ListView(
                          padding: EdgeInsets.fromLTRB(14 * k, 12 * k, 14 * k, 12 * k),
                          children: [
                            for (var i = 0; i < _chapters.length; i++) ...[
                              _chapterHeader(_chapters[i], i + 1, k),
                              SizedBox(height: 12 * k),
                              _grid(_chapters[i], k),
                              SizedBox(height: 14 * k),
                            ],
                            _nextChapter(k),
                          ],
                        ),
                ),
                if (_selected > 0) _panel(k),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(double k) => Padding(
    padding: EdgeInsets.fromLTRB(14 * k, 6 * k, 14 * k, 0),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 40 * k,
            height: 40 * k,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.3),
                colors: [Color(0xFF1D3266), Color(0xFF0C1838)],
              ),
              border: Border.all(color: Palette.gold, width: 2),
            ),
            child: Icon(Icons.chevron_left_rounded, color: goldLight, size: 26 * k),
          ),
        ),
        SizedBox(width: 10 * k),
        Expanded(child: Text('Aventure', style: titleStyle(21 * k, Colors.white))),
        Container(
          height: 32 * k,
          padding: EdgeInsets.only(left: 6 * k, right: 12 * k),
          decoration: BoxDecoration(
            color: const Color(0xCC06122F),
            borderRadius: BorderRadius.circular(16 * k),
            border: Border.all(color: const Color(0x99F2C14E), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/duel/pieces.png', width: 22 * k, height: 22 * k),
              SizedBox(width: 5 * k),
              Text('${Player.instance.talents}', style: titleStyle(17 * k, goldLight)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chapterHeader(_Chapter c, int number, double k) {
    final art = Session.instance.illustration(c.books);
    final total = c.levels.length * 3;
    final won = c.levels.fold<int>(0, (n, l) => n + (_stars['${l.$1}'] ?? const []).length);
    final title = c.name.contains(':') ? c.name.split(':').last.trim() : c.name;
    final cap = title.isEmpty ? title : title[0].toUpperCase() + title.substring(1);
    return Row(
      children: [
        Container(
          width: 62 * k,
          height: 62 * k,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12 * k),
            border: Border.all(color: const Color(0xFFC9A35A), width: 2),
          ),
          child: art == null
              ? const ColoredBox(color: Color(0xFF13234A))
              : Image.asset(art, fit: BoxFit.cover, cacheWidth: 300),
        ),
        SizedBox(width: 12 * k),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chapitre $number', style: bodyStyle(12 * k, goldLight, weight: 900)),
              Text(cap, style: titleStyle(24 * k, Colors.white)),
              Row(
                children: [
                  Image.asset('assets/aventure/etoile.png', width: 15 * k, height: 15 * k),
                  SizedBox(width: 5 * k),
                  Text('$won étoiles sur $total', style: bodyStyle(12 * k, paleText)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(_Chapter c, double k) {
    final art = Session.instance.illustration(c.books);
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9 * k,
      crossAxisSpacing: 9 * k,
      childAspectRatio: 0.66,
      children: [
        for (var i = 0; i < c.levels.length; i++)
          _LevelCard(
            number: c.levels[i].$1,
            name: c.levels[i].$2,
            art: art,
            // Chaque niveau montre un morceau différent de l'illustration du livre.
            artAlignment: Alignment(-1 + 2 * (i % 4) / 3, -0.2 + 0.4 * (i ~/ 4)),
            stars: _stars['${c.levels[i].$1}'] ?? const [],
            open: Adventure.isOpen(_stars, c.levels[i].$1),
            selected: c.levels[i].$1 == _selected,
            onTap: () {
              if (Adventure.isOpen(_stars, c.levels[i].$1)) {
                _select(c.levels[i].$1);
              } else {
                showToast(context, 'Gagne le niveau ${c.levels[i].$1 - 1} pour ouvrir celui-ci.');
              }
            },
          ),
      ],
    );
  }

  Widget _nextChapter(double k) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
    decoration: BoxDecoration(
      color: const Color(0x0AFFFFFF),
      borderRadius: BorderRadius.circular(12 * k),
      border: Border.all(color: const Color(0x40F2C14E)),
    ),
    child: Text(
      'D’autres chapitres arrivent bientôt.',
      textAlign: TextAlign.center,
      style: bodyStyle(12.5 * k, paleText),
    ),
  );

  Widget _panel(double k) {
    final level = _selected;
    final name = _chapters.expand((c) => c.levels).firstWhere((l) => l.$1 == level, orElse: () => (level, '')).$2;
    final won = _stars['$level'] ?? const [];
    return Container(
      margin: EdgeInsets.fromLTRB(12 * k, 0, 12 * k, 10 * k),
      padding: EdgeInsets.fromLTRB(12 * k, 12 * k, 12 * k, 12 * k),
      decoration: BoxDecoration(
        color: const Color(0xEB06122F),
        borderRadius: BorderRadius.circular(20 * k),
        border: Border.all(color: const Color(0x8CF2C14E), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, -10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Niveau $level · $name', textAlign: TextAlign.center, style: titleStyle(19 * k, goldLight)),
          Text('Contre le Scribe · choisis ta difficulté', style: bodyStyle(11.5 * k, paleText)),
          SizedBox(height: 16 * k),
          ListenableBuilder(
            listenable: Reglages.instance,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (d, label) in const [('lait', 'Lait'), ('manne', 'Manne'), ('solide', 'Solide')]) ...[
                  if (d != 'lait') SizedBox(width: 8 * k),
                  Opacity(
                    opacity: 1,
                    child: DifficultyCard(
                      size: 0.66,
                      difficulty: d,
                      label: label,
                      help: won.contains(d) ? '★ gagnée' : 'à gagner',
                      helpColor: won.contains(d) ? const Color(0xFF2F8A3A) : null,
                      stake: Reglages.instance.miseArcade(d),
                      selected: d == _difficulty,
                      onTap: () => setState(() => _difficulty = d),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 14 * k),
          GoldButton(
            _busy ? 'Préparation…' : 'Jouer',
            onPressed: _busy ? null : _play,
            height: 56 * k,
            fontSize: 22 * k,
            shiny: true,
            icon: Icon(Icons.play_arrow_rounded, color: Palette.ink, size: 30 * k),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final int number;
  final String name;
  final String? art;
  final Alignment artAlignment;
  final List stars;
  final bool open;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.number,
    required this.name,
    required this.art,
    required this.artAlignment,
    required this.stars,
    required this.open,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final card = Container(
      padding: EdgeInsets.all(2.5 * k),
      decoration: BoxDecoration(
        color: const Color(0xFF13234A),
        borderRadius: BorderRadius.circular(10 * k),
        border: Border.all(color: selected ? goldLight : const Color(0xFFB8924C), width: selected ? 2 : 1),
        boxShadow: [
          if (selected) const BoxShadow(color: Color(0xBFFFD66E), blurRadius: 20),
          const BoxShadow(color: Color(0x80000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF3ECDD),
          borderRadius: BorderRadius.circular(8 * k),
          border: Border.all(color: const Color(0xFFC9A35A)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 56 * k,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (art != null)
                    // Rogné à sa place : le morceau agrandi ne déborde pas sur le nom.
                    ClipRect(
                      child: Transform.scale(
                        scale: 2.2,
                        alignment: artAlignment,
                        child: Image.asset(art!, fit: BoxFit.cover, alignment: artAlignment, cacheWidth: 500),
                      ),
                    )
                  else
                    const ColoredBox(color: Color(0xFF1F3165)),
                  Positioned(
                    left: 4 * k,
                    top: 4 * k,
                    child: Container(
                      width: 20 * k,
                      height: 20 * k,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFFFFE48A), Color(0xFFE0961A)]),
                      ),
                      child: Text('$number', style: titleStyle(12 * k, Palette.ink)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(3 * k, 4 * k, 3 * k, 0),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Garamond',
                    color: Color(0xFF1D2A4A),
                    fontVariations: [FontVariation('wght', 700)],
                    height: 1.05,
                  ).copyWith(fontSize: 12 * k),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 4 * k),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final d in const ['lait', 'manne', 'solide'])
                    Opacity(
                      opacity: stars.contains(d) ? 1 : 0.3,
                      child: ColorFiltered(
                        colorFilter: stars.contains(d)
                            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                            : const ColorFilter.matrix([
                                0.3,
                                0.59,
                                0.11,
                                0,
                                0,
                                0.3,
                                0.59,
                                0.11,
                                0,
                                0,
                                0.3,
                                0.59,
                                0.11,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                        child: Image.asset('assets/aventure/etoile.png', width: 12 * k, height: 12 * k),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: open
          ? card
          : Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.center,
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.17, 0.33, 0.05, 0, 0, //
                    0.17, 0.33, 0.05, 0, 0,
                    0.17, 0.33, 0.05, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: card,
                ),
                Icon(Icons.lock_rounded, color: goldLight, size: 26 * k),
              ],
            ),
    );
  }
}
