import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../state/duel_online.dart';
import '../../state/player.dart';
import '../../state/reglages.dart';
import '../game/card_face.dart';
import '../game/table.dart';
import '../salons/salons_screen.dart';
import '../theme.dart';
import '../toast.dart';
import 'duel_match_screen.dart';

/// « Jouer en ligne » (docs/maquettes/salon.html) : la difficulté se choisit comme une carte,
/// puis la recherche d'un adversaire au hasard. Pour jouer entre amis : les salons.
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key});

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

/// Décor des écrans en ligne : ciel de nuit étoilé et paysage peint en bas.
class NightSky extends StatelessWidget {
  final Widget child;

  const NightSky({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -1.1),
        radius: 1.4,
        colors: [Color(0xFF1B3A86), Color(0xFF0B1F4D), Color(0xFF06122F)],
        stops: [0, 0.45, 0.85],
      ),
    ),
    child: Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _Stars())),
        // Le paysage peint, au-dessus de la barre de navigation ; seul le sol passe dessous.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: MediaQuery.sizeOf(context).width * 96 / 311 + MediaQuery.viewPaddingOf(context).bottom * 0.6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/duel/paysage.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF06122F), Color(0x0006122F)],
                    stops: [0, 0.35],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(child: child),
      ],
    ),
  );
}

class _Stars extends CustomPainter {
  const _Stars();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(4);
    for (var i = 0; i < 40; i++) {
      final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.55);
      canvas.drawCircle(
        p,
        0.6 + rng.nextDouble() * 0.9,
        Paint()..color = Color.fromRGBO(255, 248, 225, 0.35 + rng.nextDouble() * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_Stars old) => false;
}

enum _Step { choose, searching, found }

class _OnlineScreenState extends State<OnlineScreen> with SingleTickerProviderStateMixin {
  final _duel = DuelOnline.instance;
  _Step _step = _Step.choose;
  String _difficulty = 'lait';
  final _clock = ValueNotifier<int>(0);
  Timer? _timer;
  StreamSubscription? _matchedSub;
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _matchedSub = _duel.onMatched.listen((_) => _onMatched());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _matchedSub?.cancel();
    _ring.dispose();
    _clock.dispose();
    if (_step == _Step.searching) _duel.cancelSearch();
    super.dispose();
  }

  Future<void> _search() async {
    final stake = Reglages.instance.miseDuel(_difficulty);
    if (Player.instance.talents < stake) {
      showToast(context, 'Il te faut $stake talents pour cette difficulté.');
      return;
    }
    setState(() => _step = _Step.searching);
    _clock.value = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _clock.value++);
    final error = await _duel.search(_difficulty);
    if (error != null && mounted) {
      _stopSearch();
      showToast(context, error);
    }
  }

  void _stopSearch() {
    _timer?.cancel();
    _duel.cancelSearch();
    if (mounted) setState(() => _step = _Step.choose);
  }

  Future<void> _onMatched() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _step = _Step.found);
    // Face-à-face pendant que la partie démarre, puis la table.
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DuelMatchScreen()));
    if (mounted) setState(() => _step = _Step.choose);
  }

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return PopScope(
      canPop: _step != _Step.searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopSearch();
      },
      child: Scaffold(
        backgroundColor: Palette.night,
        body: NightSky(
          child: SafeArea(
            child: Column(
              children: [
                _topBar(k),
                Expanded(
                  child: switch (_step) {
                    _Step.choose => _choose(k),
                    _Step.searching => _searching(k),
                    _Step.found => _found(k),
                  },
                ),
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
        _RoundButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => _step == _Step.searching ? _stopSearch() : Navigator.of(context).maybePop(),
        ),
        SizedBox(width: 10 * k),
        Expanded(
          child: Text(
            _step == _Step.choose ? 'Jouer en ligne' : 'Recherche',
            style: titleStyle(21 * k, Colors.white).copyWith(
              shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2))],
            ),
          ),
        ),
        ListenableBuilder(
          listenable: Player.instance,
          builder: (context, _) => _Purse(talents: Player.instance.talents),
        ),
      ],
    ),
  );

  Widget _choose(double k) => Padding(
    padding: EdgeInsets.fromLTRB(18 * k, 14 * k, 18 * k, 16 * k),
    child: Column(
      children: [
        // Le titre et les cartes, centrés dans la place libre.
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choisis ta difficulté',
                  style: titleStyle(22 * k, goldLight).copyWith(
                    shadows: const [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
                SizedBox(height: 6 * k),
                _Ornament(width: 200 * k),
                SizedBox(height: 26 * k),
                ListenableBuilder(
                  listenable: Reglages.instance,
                  builder: (context, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (d, label, help) in const [
                        ('lait', 'Lait', 'pour commencer'),
                        ('manne', 'Manne', 'les habitués'),
                        ('solide', 'Solide', 'les connaisseurs'),
                      ]) ...[
                        if (d != 'lait') SizedBox(width: 9 * k),
                        DifficultyCard(
                          difficulty: d,
                          label: label,
                          help: help,
                          stake: Reglages.instance.miseDuel(d),
                          selected: d == _difficulty,
                          onTap: () => setState(() => _difficulty = d),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        GoldButton(
          'Trouver un adversaire',
          onPressed: _search,
          height: 60 * k,
          fontSize: 22 * k,
          shiny: true,
          icon: CrossedSwords(size: 32 * k),
        ),
        SizedBox(height: 18 * k),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: const Color(0x66F2C14E))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * k),
              child: Text('Ou joue avec tes amis', style: bodyStyle(13.5 * k, paleText)),
            ),
            Expanded(child: Container(height: 1, color: const Color(0x66F2C14E))),
          ],
        ),
        SizedBox(height: 12 * k),
        SizedBox(
          width: double.infinity,
          child: NightButton(
            'Les salons',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalonsScreen())),
            height: 50 * k,
            fontSize: 18 * k,
            icon: Icon(Icons.groups_rounded, color: goldLight, size: 26 * k),
          ),
        ),
        SizedBox(height: 110 * k),
      ],
    ),
  );

  Widget _searching(double k) {
    const labels = {'lait': 'Lait', 'manne': 'Manne', 'solide': 'Solide'};
    return Padding(
      padding: EdgeInsets.fromLTRB(18 * k, 20 * k, 18 * k, 26 * k),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  PlayerAvatar(name: Player.instance.username, color: playerColors[0], size: 64 * k),
                  SizedBox(height: 6 * k),
                  Text('Toi', style: titleStyle(17 * k, Colors.white)),
                ],
              ),
              SizedBox(width: 16 * k),
              Text(
                'VS',
                style: titleStyle(
                  26 * k,
                  Palette.gold,
                ).copyWith(shadows: const [Shadow(color: Color(0x99F2C14E), blurRadius: 14)]),
              ),
              SizedBox(width: 16 * k),
              SizedBox(
                width: 150 * k,
                height: 150 * k,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _ring,
                      child: CustomPaint(size: Size.square(150 * k), painter: _RingPainter()),
                    ),
                    CardBack(width: 70 * k),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20 * k),
          Text('Recherche d’un adversaire…', style: titleStyle(23 * k, Colors.white)),
          SizedBox(height: 6 * k),
          Text(
            '${labels[_difficulty]} · mise de ${Reglages.instance.miseDuel(_difficulty)} talents',
            style: bodyStyle(13.5 * k, paleText),
          ),
          SizedBox(height: 14 * k),
          ValueListenableBuilder<int>(
            valueListenable: _clock,
            builder: (context, s, _) => Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 18 * k, vertical: 8 * k),
                  decoration: BoxDecoration(
                    color: const Color(0xD106122F),
                    borderRadius: BorderRadius.circular(22 * k),
                    border: Border.all(color: const Color(0x80F2C14E), width: 1.5),
                  ),
                  child: Text(
                    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}',
                    style: titleStyle(22 * k, goldLight),
                  ),
                ),
                if (s >= 30)
                  Padding(
                    padding: EdgeInsets.only(top: 18 * k),
                    child: Text(
                      'Personne pour l’instant. La recherche continue ;\nrevois tes cartes en attendant !',
                      textAlign: TextAlign.center,
                      style: bodyStyle(13.5 * k, paleText),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 220 * k,
            child: NightButton('Annuler', onPressed: _stopSearch, height: 50 * k, fontSize: 17 * k),
          ),
        ],
      ),
    );
  }

  Widget _found(double k) => ListenableBuilder(
    listenable: _duel,
    builder: (context, _) {
      final adv = (_duel.view['adversaire'] as Map?) ?? const {};
      final name = '${adv['pseudo'] ?? 'Adversaire'}';
      const labels = {'lait': 'Lait', 'manne': 'Manne', 'solide': 'Solide'};
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Versus(name: Player.instance.username, level: '', color: playerColors[0], left: true),
          SizedBox(height: 18 * k),
          Container(
            width: 96 * k,
            height: 96 * k,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.2, -0.3),
                colors: [Color(0xFFFFF1B0), Color(0xFFF2C14E), Color(0xFFB8781A)],
                stops: [0, 0.5, 1],
              ),
              boxShadow: [BoxShadow(color: Color(0xCCFFD66E), blurRadius: 50)],
            ),
            child: Text('VS', style: titleStyle(40 * k, Palette.ink)),
          ),
          SizedBox(height: 18 * k),
          _Versus(
            name: name,
            level: adv['niveau'] == null ? '' : 'Niveau ${adv['niveau']}',
            color: playerColors[1],
            left: false,
          ),
          SizedBox(height: 40 * k),
          Text('La partie commence !', style: titleStyle(23 * k, Colors.white)),
          SizedBox(height: 8 * k),
          Text(
            '${labels[_difficulty]} · ${Reglages.instance.miseDuel(_difficulty)} talents chacun',
            style: bodyStyle(14 * k, goldLight, weight: 900),
          ),
        ],
      );
    },
  );
}

class _Versus extends StatelessWidget {
  final String name;
  final String level;
  final Color color;
  final bool left;

  const _Versus({required this.name, required this.level, required this.color, required this.left});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final texts = Column(
      crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          name,
          style: titleStyle(26 * k, Colors.white).copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 5)]),
        ),
        if (level.isNotEmpty) Text(level, style: bodyStyle(13 * k, goldLight)),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 26 * k),
      child: Row(
        mainAxisAlignment: left ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: left
            ? [PlayerAvatar(name: name, color: color, size: 92 * k), SizedBox(width: 12 * k), texts]
            : [texts, SizedBox(width: 12 * k), PlayerAvatar(name: name, color: color, size: 92 * k)],
      ),
    );
  }
}

/// Image et liseré de chaque difficulté (docs/maquettes/en_ligne_difficulte.html, piste A).
const _difficultyArt = {
  'lait': ('assets/duel/lait.jpg', Color(0xFF4FAE5C)),
  'manne': ('assets/duel/manne.jpg', Color(0xFF3F78D8)),
  'solide': ('assets/duel/pain.jpg', Color(0xFF8A5BC4)),
};

/// Une difficulté choisie comme une carte du jeu : cadre bleu nuit, l'image de la difficulté
/// en haut (le lait, la manne, le pain), le nom en serif et la mise sur le parchemin.
class DifficultyCard extends StatelessWidget {
  /// Taille relative (1 : écran « En ligne » ; plus petit dans le panneau de l'aventure).
  final double size;
  final Color? helpColor;
  final String difficulty;
  final String label;
  final String help;
  final int stake;
  final bool selected;
  final VoidCallback onTap;

  const DifficultyCard({
    super.key,
    this.size = 1,
    this.helpColor,
    required this.difficulty,
    required this.label,
    required this.help,
    required this.stake,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context) * size;
    final (art, color) = _difficultyArt[difficulty]!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, selected ? -12 * k : 0, 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100 * k,
              height: 186 * k,
              padding: EdgeInsets.all(3 * k),
              decoration: BoxDecoration(
                color: const Color(0xFF13234A),
                borderRadius: BorderRadius.circular(10 * k),
                border: Border.all(color: selected ? goldLight : const Color(0xFFB8924C), width: selected ? 2.5 : 1),
                boxShadow: [
                  if (selected) const BoxShadow(color: Color(0xCCFFD66E), blurRadius: 28),
                  const BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 8)),
                ],
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8 * k),
                  border: Border.all(color: const Color(0xFFC9A35A)),
                  gradient: const RadialGradient(
                    center: Alignment(0, 0.6),
                    colors: [Color(0xFFF8F2E6), Color(0xFFEFE6D4)],
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 92 * k,
                      width: double.infinity,
                      child: Image.asset(art, fit: BoxFit.cover, alignment: const Alignment(0, -0.1), cacheWidth: 400),
                    ),
                    Container(height: 4 * k, color: color),
                    SizedBox(height: 9 * k),
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Garamond',
                        color: Color(0xFF1D2A4A),
                        fontVariations: [FontVariation('wght', 700)],
                        height: 1,
                      ).copyWith(fontSize: 21 * k),
                    ),
                    SizedBox(height: 8 * k),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/duel/pieces.png', width: 20 * k, height: 20 * k),
                        SizedBox(width: 4 * k),
                        Text('$stake', style: titleStyle(20 * k, const Color(0xFF6B4310))),
                      ],
                    ),
                    SizedBox(height: 3 * k),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4 * k),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(help, maxLines: 1, style: bodyStyle(10.5 * k, helpColor ?? const Color(0xFF8A7A66), weight: helpColor == null ? 800 : 900)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: -12 * k,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 26 * k,
                    height: 26 * k,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFE48A), Color(0xFFE0961A)],
                      ),
                      border: Border.all(color: const Color(0xFF6B4310), width: 1.5),
                      boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 5, offset: Offset(0, 2))],
                    ),
                    child: Icon(Icons.check_rounded, size: 17 * k, color: const Color(0xFF3A2412)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Filet doré avec un losange au centre, sous le titre.
class _Ornament extends StatelessWidget {
  final double width;

  const _Ornament({required this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 10,
    child: Row(
      children: [
        Expanded(
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x00F2C14E), Color(0xFFF2C14E)])),
          ),
        ),
        Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: const Color(0xFFF2C14E),
          ),
        ),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF2C14E), Color(0x00F2C14E)])),
          ),
        ),
      ],
    ),
  );
}

class _Purse extends StatelessWidget {
  final int talents;

  const _Purse({required this.talents});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Container(
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
          Text('$talents', style: titleStyle(17 * k, goldLight)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40 * k,
        height: 40 * k,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(center: Alignment(-0.2, -0.3), colors: [Color(0xFF1D3266), Color(0xFF0C1838)]),
          border: Border.all(color: Palette.gold, width: 2),
        ),
        child: Icon(icon, color: goldLight, size: 26 * k),
      ),
    );
  }
}

/// Anneau doré qui tourne autour de l'adversaire à venir.
class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x59F2C14E),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      0,
      pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: const [Color(0x00FFE39A), Color(0xFFFFE39A)],
          stops: const [0, 0.25],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}
