import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/adventure.dart';
import '../../state/quiz.dart';
import '../../state/online.dart';
import '../../state/player.dart';
import '../../state/reglages.dart';
import '../../state/session.dart';
import '../game/table.dart';
import 'quiz_screen.dart';
import '../online/online_screen.dart';
import '../theme.dart';
import '../toast.dart';
import '../profile/profile_screen.dart';

/// L'aventure contre le Scribe (docs/maquettes/aventure.html, piste C « le livre du chapitre ») :
/// la peinture du livre en haut, son enseigne, les niveaux en petites cartes, puis le panneau du
/// niveau choisi avec ses trois difficultés et « Jouer ».
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
      final r = await Quiz.state();
      if (!mounted) return;
      setState(() => _questions = r.questions);
      _select(Adventure.currentLevel(r.stars, _levelCount));
    } catch (_) {
      // Hors ligne : la carte s'affiche avec la progression gardée.
    }
  }

  int get _levelCount => _chapters.fold(0, (n, c) => n + c.levels.length);

  AdventureStars get _stars => Player.instance.adventureStars;

  /// Questions disponibles par étape et difficulté, selon le serveur (vide : pas encore lu).
  Map _questions = const {};

  bool _ready(int level, String difficulty) {
    final n = (_questions['$level'] as Map?)?[difficulty];
    return n == null || (n as num) >= Reglages.instance['aventure_questions'];
  }

  void _select(int level) {
    setState(() {
      _selected = level;
      _difficulty = Adventure.suggestedDifficulty(_stars, level);
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
    if (!_ready(_selected, _difficulty)) {
      showToast(context, 'Cette étape n’a pas encore ses questions dans cette difficulté.');
      return;
    }
    final name = _chapters.expand((c) => c.levels).firstWhere((l) => l.$1 == _selected, orElse: () => (_selected, '')).$2;
    setState(() => _busy = true);
    final quiz = Quiz(_selected, _difficulty);
    try {
      final first = await quiz.start();
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizScreen(quiz: quiz, first: first, levelName: 'Niveau $_selected · $name'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, Online.describe(e));
      return;
    }
    if (mounted) _select(Adventure.currentLevel(_stars, _levelCount));
  }

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Boutons Android clairs sur la nuit du panneau, sans le voile blanc que le système ajoute sinon.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _deepNight,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: _deepNight,
        body: ListenableBuilder(
          listenable: Player.instance,
          builder: (context, _) => Stack(
            children: [
              _backdrop(k),
              Positioned.fill(
                child: Column(
                  children: [
                    SafeArea(bottom: false, child: _topBar(k)),
                    Expanded(
                      child: _chapters.isEmpty
                          ? const Center(child: CircularProgressIndicator(color: Palette.gold))
                          : _book(k),
                    ),
                    // Le panneau descend jusqu'au bord de l'écran, sous la barre de navigation.
                    if (_selected > 0) _panel(k),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La peinture du livre (celui du niveau choisi), qui se fond dans la nuit sous les cartes.
  Widget _backdrop(double k) {
    final chapter = _chapters.where((c) => c.levels.any((l) => l.$1 == _selected)).firstOrNull ?? _chapters.firstOrNull;
    final art = chapter == null ? null : Session.instance.illustration(chapter.books);
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: MediaQuery.paddingOf(context).top + 390 * k,
      child: art == null
          ? const SizedBox.shrink()
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(art, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.2, 0.6, 1],
                      colors: [Color(0xB306122F), Color(0x0006122F), Color(0x0006122F), _deepNight],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _topBar(double k) => Padding(
    padding: EdgeInsets.fromLTRB(14 * k, 6 * k, 14 * k, 0),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: 'Retour',
          child: GestureDetector(
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
        ),
        SizedBox(width: 10 * k),
        Expanded(
          child: Text('Aventure', maxLines: 1, style: titleStyle(21 * k, Colors.white).copyWith(shadows: _textShadow)),
        ),
        Container(
          constraints: BoxConstraints(minHeight: 32 * k),
          padding: EdgeInsets.only(left: 6 * k, right: 12 * k),
          decoration: BoxDecoration(
            color: const Color(0xE606122F),
            borderRadius: BorderRadius.circular(24 * k),
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

  /// Les chapitres, posés juste au-dessus du panneau : la place libre montre la peinture.
  /// Les cartes prennent la hauteur disponible ; sur un très petit écran seulement, on fait défiler.
  Widget _book(double k) => LayoutBuilder(
    builder: (context, box) {
      final text = MediaQuery.textScalerOf(context);
      // Hauteur de tout sauf les cartes : enseigne, mention de la suite et espacements.
      final nextHeight = text.scale(11.5 * k) * 1.1 + 8 * k;
      final around = text.scale(12 * k) * 1.1 + text.scale(23 * k) * 1.1 + nextHeight + 51 * k;
      // Sur un écran court, la mention de la suite laisse sa place aux cartes.
      final short = (box.maxHeight - around) / 2 < 98 * k;
      final cardHeight = ((box.maxHeight - around + (short ? nextHeight : 0)) / 2).clamp(84 * k, 134 * k);
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * k),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < _chapters.length; i++) ...[
                  SizedBox(height: 8 * k),
                  _chapterSign(_chapters[i], i + 1, k),
                  SizedBox(height: 10 * k),
                  _grid(_chapters[i], cardHeight, k),
                ],
                if (!short) ...[
                  SizedBox(height: 8 * k),
                  Text(
                    'D’autres chapitres arrivent bientôt.',
                    textAlign: TextAlign.center,
                    style: bodyStyle(11.5 * k, paleText).copyWith(shadows: _textShadow),
                  ),
                ],
                SizedBox(height: 8 * k),
              ],
            ),
          ),
        ),
      );
    },
  );

  /// L'enseigne du chapitre, en bois comme le ruban du titre du jeu.
  Widget _chapterSign(_Chapter c, int number, double k) {
    final total = c.levels.length * 9;
    final won = c.levels.fold<int>(0, (n, l) => n + Adventure.levelTotal(_stars, l.$1));
    final title = c.name.contains(':') ? c.name.split(':').last.trim() : c.name;
    final cap = title.isEmpty ? title : title[0].toUpperCase() + title.substring(1);
    return Container(
      padding: EdgeInsets.fromLTRB(14 * k, 6 * k, 12 * k, 7 * k),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8B552A), Color(0xFF532C14)],
        ),
        borderRadius: BorderRadius.circular(12 * k),
        border: Border.all(color: const Color(0xFFE8B85A), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chapitre $number', style: bodyStyle(12 * k, goldLight, weight: 900)),
                Text(cap, style: titleStyle(23 * k, Palette.cream).copyWith(shadows: _textShadow)),
              ],
            ),
          ),
          SizedBox(width: 8 * k),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 6 * k),
            decoration: BoxDecoration(color: const Color(0x73200F04), borderRadius: BorderRadius.circular(20 * k)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/aventure/etoile.png', width: 17 * k, height: 17 * k),
                SizedBox(width: 5 * k),
                // En français, zéro et un restent au singulier.
                Text('$won ${won < 2 ? 'étoile' : 'étoiles'} sur $total', style: bodyStyle(12 * k, Palette.cream)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(_Chapter c, double cardHeight, double k) {
    final art = Session.instance.illustration(c.books);
    Widget card(int i) {
      final level = c.levels[i].$1;
      final open = Adventure.isOpen(_stars, level);
      return _LevelCard(
        number: level,
        name: c.levels[i].$2,
        art: art,
        // Chaque niveau montre un autre détail de la peinture du livre.
        artAlignment: _details[i % _details.length],
        stars: [for (final d in Adventure.difficulties) if (Adventure.stars(_stars, level, d) > 0) d],
        open: open,
        selected: level == _selected,
        onTap: () {
          if (open) {
            _select(level);
          } else {
            showToast(context, 'Gagne le niveau ${level - 1} pour ouvrir celui-ci.');
          }
        },
      );
    }

    // Les noms grossissent avec le texte du téléphone, mais pas au point de sortir de leur carte.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Column(
        children: [
          for (var row = 0; row < c.levels.length; row += 4) ...[
            if (row > 0) SizedBox(height: 8 * k),
            SizedBox(
              height: cardHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = row; i < row + 4; i++) ...[
                    if (i > row) SizedBox(width: 8 * k),
                    Expanded(child: i < c.levels.length ? card(i) : const SizedBox()),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel(double k) {
    final level = _selected;
    final name = _chapters.expand((c) => c.levels).firstWhere((l) => l.$1 == level, orElse: () => (level, '')).$2;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: const EdgeInsets.only(top: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFD9AE55),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22 * k)),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, -8))],
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(14 * k, 9 * k, 14 * k, bottom + 10 * k),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B3573), _deepNight],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(21 * k)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Niveau $level · $name', style: titleStyle(19 * k, goldLight)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Le Scribe te pose ${Reglages.instance['aventure_questions']} questions · choisis ta difficulté', style: bodyStyle(11.5 * k, paleText)),
            ),
            SizedBox(height: 14 * k),
            ListenableBuilder(
              listenable: Reglages.instance,
              builder: (context, _) => Row(
                children: [
                  for (final (d, label) in const [('lait', 'Lait'), ('manne', 'Manne'), ('solide', 'Solide')]) ...[
                    if (d != 'lait') SizedBox(width: 9 * k),
                    Expanded(
                      child: DifficultyCard(
                        compact: true,
                        difficulty: d,
                        label: label,
                        help: !_ready(level, d)
                            ? 'bientôt'
                            : switch (Adventure.stars(_stars, level, d)) { 3 => 'parfait', 0 => 'à gagner', _ => 'à améliorer' },
                        helpColor: Adventure.stars(_stars, level, d) == 3 ? const Color(0xFF24732F) : null,
                        stars: Adventure.stars(_stars, level, d),
                        selected: d == _difficulty,
                        onTap: () => setState(() => _difficulty = d),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 10 * k),
            GoldButton(
              _busy ? 'Préparation…' : 'Jouer',
              onPressed: _busy ? null : _play,
              height: 52 * k,
              fontSize: 22 * k,
              shiny: true,
              icon: Icon(Icons.play_arrow_rounded, color: Palette.ink, size: 30 * k),
            ),
          ],
        ),
      ),
    );
  }
}

const _deepNight = Color(0xFF06122F);

const _textShadow = [Shadow(color: Color(0xCC000000), blurRadius: 5, offset: Offset(0, 1.5))];

/// Les huit détails de la peinture montrés par les cartes : ciel, cime, rive, tronc…
const _details = [
  Alignment(-0.75, -0.3),
  Alignment(0.1, -0.55),
  Alignment(-0.85, 0.45),
  Alignment(0.15, 0.3),
  Alignment(0.8, -0.25),
  Alignment(-0.3, 0.8),
  Alignment(0.65, 0.4),
  Alignment(0.85, 0.9),
];

/// Un niveau en petite carte : le détail peint en haut, le nom dessous. Ouverte, la carte est
/// sur parchemin avec ses trois étoiles ; fermée, la peinture est dans la nuit, avec un cadenas.
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
    final nameSize = MediaQuery.textScalerOf(context).scale(12 * k);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Le liseré plus épais de la carte choisie ne rétrécit pas son contenu.
        padding: EdgeInsets.all(selected ? 2.5 * k - 1.5 : 2.5 * k),
        decoration: BoxDecoration(
          color: const Color(0xFF13234A),
          borderRadius: BorderRadius.circular(10 * k),
          border: Border.all(color: selected ? goldLight : const Color(0xFFD9AE55), width: selected ? 2.5 : 1),
          boxShadow: [
            if (selected) const BoxShadow(color: Color(0xE6FFD66E), blurRadius: 18, spreadRadius: 2),
            const BoxShadow(color: Color(0x80000000), blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8 * k),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _picture(k)),
              Container(
                // Deux lignes de nom et la rangée d'étoiles.
                height: nameSize * 2.1 + 21 * k,
                color: open ? const Color(0xFFF8EFDC) : const Color(0xFF1A2F66),
                padding: EdgeInsets.symmetric(horizontal: k),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Garamond',
                            fontSize: 12 * k,
                            color: open ? const Color(0xFF1D2A4A) : const Color(0xFFE9E4D6),
                            fontVariations: const [FontVariation('wght', 700)],
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                    if (open)
                      Padding(
                        padding: EdgeInsets.only(bottom: 3 * k),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final d in const ['lait', 'manne', 'solide']) _star(stars.contains(d), k),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picture(double k) => Stack(
    fit: StackFit.expand,
    children: [
      if (art != null)
        // Rogné à sa place : le détail agrandi ne déborde pas sur le nom.
        ClipRect(
          child: Transform.scale(
            scale: 2.2,
            alignment: artAlignment,
            child: Image.asset(art!, fit: BoxFit.cover, alignment: artAlignment, cacheWidth: 500),
          ),
        )
      else
        const ColoredBox(color: Color(0xFF1F3165)),
      // La nuit sur un niveau fermé : la peinture se devine encore, en couleurs.
      if (!open) const ColoredBox(color: Color(0x990B1F4D)),
      Positioned(
        left: 3 * k,
        top: 3 * k,
        child: Container(
          width: 20 * k,
          height: 20 * k,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: open ? null : const Color(0xE606122F),
            gradient: open ? const LinearGradient(colors: [Color(0xFFFFE48A), Color(0xFFE0961A)]) : null,
            border: Border.all(color: open ? const Color(0xFF6B4310) : const Color(0xFFD9AE55)),
          ),
          child: Text(
            '$number',
            textScaler: TextScaler.noScaling,
            style: titleStyle(12 * k, open ? Palette.ink : goldLight),
          ),
        ),
      ),
      // En bas à droite de l'image : ni sur le numéro, ni sur le nom.
      if (!open)
        Positioned(
          right: 4 * k,
          bottom: 4 * k,
          child: Container(
            width: 24 * k,
            height: 24 * k,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFE48A), Color(0xFFE0961A)],
              ),
              boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 5, offset: Offset(0, 2))],
            ),
            child: Icon(Icons.lock_rounded, color: Palette.ink, size: 15 * k),
          ),
        ),
    ],
  );

  /// Une étoile gagnée en or ; à gagner, sa silhouette sur le parchemin.
  Widget _star(bool won, double k) => Image.asset(
    'assets/aventure/etoile.png',
    width: 15 * k,
    height: 15 * k,
    color: won ? null : const Color(0x401D2A4A),
    colorBlendMode: won ? null : BlendMode.srcIn,
  );
}
