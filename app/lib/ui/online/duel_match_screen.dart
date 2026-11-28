import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/card_data.dart';
import '../../state/duel_online.dart';
import '../../state/online.dart';
import '../../state/player.dart';
import '../../state/reglages.dart';
import '../../state/session.dart';
import '../game/burn.dart';
import '../game/card_face.dart';
import '../game/celebration.dart';
import '../game/table.dart';
import '../theme.dart';
import '../../state/sound.dart';

/// Un duel en ligne, mené par le serveur (server/src/duel_en_ligne.ts) : l'écran ne fait
/// qu'afficher la dernière vue reçue et envoyer les choix du joueur. Même table que la partie
/// à deux : main ouverte devant soi, carte au centre, feu doré, fête de la victoire.
class DuelMatchScreen extends StatefulWidget {
  /// La partie affichée (le duel en ligne par défaut).
  final MatchSource? source;

  const DuelMatchScreen({super.key, this.source});

  @override
  State<DuelMatchScreen> createState() => _DuelMatchScreenState();
}

class _DuelMatchScreenState extends State<DuelMatchScreen> with SingleTickerProviderStateMixin {
  late final MatchSource _duel = widget.source ?? DuelOnline.instance;
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;

  // Choix faits sur cet écran, en attendant la vue suivante.
  int _selected = -1;
  bool _played = false;
  String? _starterChoice;
  String? _answer;
  bool _continued = false;
  bool _rematch = false;
  bool _quitAsked = false;
  bool _endApplied = false;

  /// Coup déjà brûlé (la vue « résultat » revient à chaque « Continuer »).
  String _burnt = '';
  String _etape = '';
  int _ticked = 0;

  @override
  void initState() {
    super.initState();
    _duel.addListener(_onView);
    _clock.addListener(_tickSound);
    _ticker = createTicker((_) => _clock.value = _left())..start();
    _onView();
  }

  @override
  void dispose() {
    _duel.removeListener(_onView);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _v => _duel.view;
  String get _step => '${_v['etape'] ?? 'attente'}';
  bool get _iPose => _v['poseur'] == 'moi';
  Map get _adv => (_v['adversaire'] as Map?) ?? const {};
  String get _advName => '${_adv['pseudo'] ?? 'Adversaire'}';
  Map? get _coup => _v['coup'] as Map?;

  double _left() {
    final t = (_v['temps'] as num?)?.toDouble() ?? 0;
    if (_v['pause'] != null) return t;
    return max(0, t - DateTime.now().difference(_duel.viewAt).inMilliseconds / 1000);
  }

  double get _total => switch (_step) {
        'depart' => Reglages.instance['duel_depart_s'],
        'choisir' => Reglages.instance['duel_choisir_s'],
        'repondre' => Reglages.instance['duel_repondre_s'],
        'resultat' => Reglages.instance['duel_resultat_s'],
        'finie' => Reglages.instance['duel_revanche_s'],
        _ => 1,
      }.toDouble();

  /// Une nouvelle étape efface les choix de la précédente.
  void _onView() {
    if (!mounted) return;
    if (_step != _etape) {
      _etape = _step;
      _ticked = 0;
      _selected = -1;
      _played = false;
      _answer = null;
      _continued = false;
      if (_step != 'annonce') _starterChoice = null;
      if (_step != 'finie') {
        _rematch = false;
        _endApplied = false;
      }
      _stepSound();
    }
    final fin = _v['fin'] as Map?;
    if (fin != null && !_endApplied) {
      _endApplied = true;
      Sound.instance.play(fin['gagne'] == true ? 'victoire' : 'defaite');
      Online.instance.applyEnd(talents: (fin['talents'] as num?)?.toInt(), xp: (fin['xpTotal'] as num?)?.toInt());
    }
    setState(() {});
  }

  void _send(int op, [Map<String, dynamic> data = const {}]) => _duel.send(op, data);

  /// Le son d'une nouvelle étape : carte posée, résultat du départ ou d'un coup.
  void _stepSound() {
    final c = _coup;
    switch (_step) {
      case 'repondre':
        Sound.instance.play('carte');
      case 'annonce' when c != null:
        Sound.instance.play(c['jeCommence'] == true ? 'juste' : 'faux');
      case 'resultat' when c != null && c['juste'] != null:
        // Ta carte trouvée par l'autre : mauvaise nouvelle pour toi.
        final good = c['mienne'] == true ? c['juste'] != true : c['juste'] == true;
        Sound.instance.play(good ? 'juste' : 'faux');
    }
  }

  void _tickSound() {
    final second = _clock.value.ceil();
    if (second >= 1 && second <= 5 && second != _ticked && const ['depart', 'choisir', 'repondre'].contains(_step)) {
      _ticked = second;
      Sound.instance.play('tic', volume: 0.6);
    }
  }

  Future<void> _quit() async {
    final over = _step == 'finie' || _step == 'annulee';
    if (!over) {
      _send(DuelOp.abandonner);
    }
    await _duel.leave();
    if (mounted) Navigator.of(context).pop();
  }

  CardData _card(Object? json) => CardData.fromJson(((json as Map?) ?? const {}).cast<String, dynamic>());

  // ---------------------------------------------------------------- Affichage

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _quitAsked = !_quitAsked);
      },
      child: Scaffold(
        backgroundColor: Palette.night,
        body: Stack(
          children: [
            Positioned.fill(child: GameBackground(art: _art)),
            Positioned.fill(
              child: Padding(padding: EdgeInsets.only(top: pad.top + 6 * k, bottom: pad.bottom), child: _body(k)),
            ),
            if (_step == 'finie' && (_v['fin'] as Map?)?['gagne'] == true) const Positioned.fill(child: Celebration()),
            Positioned(
              left: 8 * k,
              top: pad.top + 2 * k,
              child: IconButton(
                onPressed: () => setState(() => _quitAsked = true),
                icon: Icon(Icons.close_rounded, color: Colors.white70, size: 22 * k),
              ),
            ),
            if (_v['pause'] != null) _banner(k, _pauseText()),
            if (_duel.linkLost) _banner(k, 'Connexion perdue… reconnexion en cours.'),
            if (_quitAsked) _quitLayer(k),
          ],
        ),
      ),
    );
  }

  String? get _art {
    if (_step == 'choisir' && _iPose && _selected >= 0) {
      final main = (_v['main'] as List?) ?? const [];
      if (_selected < main.length) return Session.instance.illustration(_card((main[_selected] as Map)['carte']).books);
    }
    final c = _coup;
    if (_step == 'resultat' && c != null && c['juste'] == true) return Session.instance.illustration(_card(c['carte']).books);
    return null;
  }

  String _pauseText() {
    final p = _v['pause'] as Map;
    return p['adversaireAbsent'] == true
        ? '$_advName s’est déconnecté. Il a ${p['reconnexion']} s pour revenir.'
        : 'Partie en pause, reconnexion…';
  }

  Widget _body(double k) => switch (_step) {
        'depart' || 'annonce' => _starter(k),
        'choisir' => _iPose ? _choose(k) : _waitChoose(k),
        'repondre' => _iPose ? _watchAnswer(k) : _answerView(k),
        'resultat' => _result(k),
        'finie' => _end(k),
        'annulee' => _cancelled(k),
        _ => _waiting(k, 'En attente de l’adversaire…'),
      };

  Widget _opponent(double k, String status) => OpponentRow(
        name: _advName,
        color: playerColors[1],
        status: status,
        cards: (_v['mainAdverse'] as num?)?.toInt() ?? 0,
        k: k,
      );

  Widget _timer(double size) => ValueListenableBuilder<double>(
        valueListenable: _clock,
        builder: (context, left, _) => TimerRing(left: left, total: _total, size: size),
      );

  Widget _waiting(double k, String text) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Palette.gold),
            SizedBox(height: 16 * k),
            Text(text, textAlign: TextAlign.center, style: titleStyle(19 * k, Colors.white)),
          ],
        ),
      );

  // ---- Question de départ : le premier qui trouve commence.
  Widget _starter(double k) {
    final d = (_v['depart'] as Map?) ?? const {};
    final c = _coup;
    final announce = _step == 'annonce' && c != null && c['type'] == 'depart';
    final options = [for (final o in (d['propositions'] as List? ?? const [])) '$o'];
    String? message;
    if (announce) {
      final mine = c['parMoi'] == true;
      final who = c['jeCommence'] == true ? 'Tu commences.' : '$_advName commence.';
      message = mine
          ? (c['juste'] == true ? 'Tu as trouvé ! $who' : 'Mauvaise réponse. $who')
          : (c['juste'] == true ? '$_advName a trouvé. $who' : '$_advName s’est trompé. $who');
    }
    return Column(
      children: [
        SizedBox(height: 34 * k),
        _opponent(k, 'question de départ'),
        const Spacer(),
        if (!announce) ...[
          _timer(56 * k),
          SizedBox(height: 12 * k),
          Text('Le premier qui trouve commence', style: titleStyle(18 * k, Colors.white)),
          SizedBox(height: 12 * k),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * k),
            child: _parchment(k, [
              Text(
                '${d['question'] ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Garamond', color: Color(0xFF1D2A4A), fontVariations: [FontVariation('wght', 700)], height: 1.2)
                    .copyWith(fontSize: 20 * k),
              ),
              SizedBox(height: 10 * k),
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) SizedBox(height: 6 * k),
                AnswerPill(
                  u: 3.4 * k,
                  letter: letters[i],
                  text: options[i],
                  mark: _starterChoice == null ? Mark.none : (options[i] == _starterChoice ? Mark.right : Mark.dim),
                  keepLetter: true,
                  onTap: _starterChoice != null
                      ? null
                      : () {
                          setState(() => _starterChoice = options[i]);
                          _send(DuelOp.depart, {'choix': options[i]});
                        },
                ),
              ],
            ]),
          ),
        ] else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * k),
            child: Text(message!, textAlign: TextAlign.center, style: titleStyle(26 * k, Palette.gold)),
          ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _parchment(double k, List<Widget> children) => Container(
        padding: EdgeInsets.fromLTRB(12 * k, 12 * k, 12 * k, 12 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * k),
          gradient: const RadialGradient(center: Alignment(0, -0.4), radius: 1.2, colors: [Color(0xFFF8F2E6), Color(0xFFEFE6D4)]),
          border: Border.all(color: const Color(0xFFC9A35A), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  // ---- Ma main.
  List<Map> get _hand => [for (final c in (_v['main'] as List? ?? const [])) c as Map];

  /// Vue du propriétaire : la bonne réponse et les fausses montrées, dans l'ordre alphabétique.
  List<String> _ownerOptions(Map entry) {
    final c = _card(entry['carte']);
    return [c.answer, for (final f in (entry['fausses'] as List? ?? const [])) '$f']..sort();
  }

  Widget _handFan(double k, {bool interactive = false, double scale = 1}) {
    final hand = _hand;
    return HandFan(
      count: hand.length,
      selected: interactive ? _selected : -1,
      onTap: interactive && !_played ? (i) => setState(() => _selected = i) : null,
      k: k,
      height: 120 * k * scale,
      scale: scale,
      card: (i, w) => CardFace(data: _card(hand[i]['carte']), options: _ownerOptions(hand[i]), owner: true, width: w),
    );
  }

  double _fit(BoxConstraints c, double share) => min(c.maxWidth * share, c.maxHeight / cardRatio);

  Widget _choose(double k) {
    final hand = _hand;
    return Column(
      children: [
        SizedBox(height: 34 * k),
        _opponent(k, '${(_v['mainAdverse'] as num?)?.toInt() ?? 0} cartes'),
        SizedBox(height: 8 * k),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16 * k),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choisis une question à poser à $_advName', style: titleStyle(17 * k, Colors.white)),
                    Text('Touche une carte pour la voir en grand', style: bodyStyle(11 * k, paleText)),
                  ],
                ),
              ),
              SizedBox(width: 10 * k),
              _timer(52 * k),
            ],
          ),
        ),
        SizedBox(height: 8 * k),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = _fit(c, 0.74);
              return Center(
                child: _selected >= 0 && _selected < hand.length
                    ? CardFace(data: _card(hand[_selected]['carte']), options: _ownerOptions(hand[_selected]), owner: true, width: w)
                    : CardBack(width: w * cardRatio / backRatio),
              );
            },
          ),
        ),
        SizedBox(height: 10 * k),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 70 * k),
          child: GoldButton(
            'Poser cette carte',
            onPressed: _selected < 0 || _played
                ? null
                : () {
                    setState(() => _played = true);
                    _send(DuelOp.jouer, {'index': _selected});
                  },
            height: 42 * k,
            fontSize: 19 * k,
          ),
        ),
        SizedBox(height: 8 * k),
        _handFan(k, interactive: true),
        SizedBox(height: 4 * k),
      ],
    );
  }

  Widget _waitChoose(double k) => Column(
        children: [
          SizedBox(height: 34 * k),
          _opponent(k, 'choisit une carte…'),
          const Spacer(),
          _timer(64 * k),
          SizedBox(height: 14 * k),
          Text('$_advName choisit la question\nqu’il va te poser', textAlign: TextAlign.center, style: titleStyle(20 * k, Colors.white)),
          const Spacer(),
          _handFan(k, scale: 0.5),
          SizedBox(height: 8 * k),
        ],
      );

  Widget _answerView(double k) {
    final carte = (_v['carte'] as Map?) ?? const {};
    final data = _card(carte);
    final options = [for (final o in (carte['propositions'] as List? ?? const [])) '$o'];
    final choice = _answer;
    return Column(
      children: [
        SizedBox(height: 34 * k),
        _opponent(k, 'a posé une carte'),
        SizedBox(height: 10 * k),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = _fit(c, 0.84);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  CardFace(
                    data: data,
                    options: options,
                    width: w,
                    hideBook: true,
                    footer: 'Carte de $_advName',
                    marks: choice == null ? const {} : {for (final o in options) o: o == choice ? Mark.right : Mark.dim},
                    onAnswer: choice == null
                        ? (o) {
                            setState(() => _answer = o);
                            _send(DuelOp.repondre, {'choix': o});
                          }
                        : null,
                  ),
                  Positioned(right: 0, top: -10 * k, child: _timer(56 * k)),
                ],
              );
            },
          ),
        ),
        SizedBox(height: 8 * k),
        Instruction(choice == null ? 'Touche la bonne réponse' : 'Réponse envoyée…', k: k),
        _handFan(k, scale: 0.5),
        SizedBox(height: 4 * k),
      ],
    );
  }

  Widget _watchAnswer(double k) {
    final carte = (_v['carte'] as Map?) ?? const {};
    final options = [for (final o in (carte['propositions'] as List? ?? const [])) '$o'];
    return Column(
      children: [
        SizedBox(height: 34 * k),
        _opponent(k, 'réfléchit…'),
        SizedBox(height: 10 * k),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CardFace(data: _card(carte), options: options, owner: true, width: _fit(c, 0.84)),
                Positioned(right: 0, top: -10 * k, child: _timer(56 * k)),
              ],
            ),
          ),
        ),
        SizedBox(height: 8 * k),
        Instruction('$_advName cherche la réponse…', k: k),
        SizedBox(height: 12 * k),
      ],
    );
  }

  // ---- Résultat d'un coup.
  Widget _result(double k) {
    final c = _coup ?? const {};
    if (c['type'] != 'coup') return _waiting(k, '');
    final mine = c['mienne'] == true;
    final right = c['juste'] == true;
    final data = _card(c['carte']);
    final options = [for (final o in (c['presentees'] as List? ?? const [])) '$o'];
    final choice = '${c['choix'] ?? ''}';
    final timedOut = c['tempsEcoule'] == true;
    final key = '${data.question}|$choice|${c['presentees']}';
    final waitingOther = _continued || (_v['continuer'] as Map?)?['moi'] == true;
    final continueButton = Padding(
      padding: EdgeInsets.symmetric(horizontal: 70 * k),
      child: GoldButton(
        waitingOther ? 'En attente de $_advName…' : 'Continuer',
        onPressed: waitingOther
            ? null
            : () {
                setState(() => _continued = true);
                _send(DuelOp.continuer);
              },
        height: 46 * k,
        fontSize: 18 * k,
      ),
    );
    if (right) {
      final title = mine ? '$_advName a trouvé ta carte' : 'Bonne réponse !';
      final panel = _RevealPanel(title: title, good: !mine, data: data, button: continueButton);
      return Column(
        children: [
          SizedBox(height: 34 * k),
          _opponent(k, mine ? 'a détruit ta carte' : 'perd une carte'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final w = _fit(cons, 0.8);
                final burnt = _burnt == key;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!burnt)
                      FeuDore(
                        key: ValueKey(key),
                        size: Size(w, w * cardRatio),
                        onConsumed: () {
                          if (mounted) setState(() => _burnt = key);
                        },
                        child: CardFace(
                          data: data,
                          options: options,
                          width: w,
                          owner: mine,
                          marks: {data.answer: Mark.right},
                          footer: mine ? 'Ta carte' : 'Carte de $_advName',
                        ),
                      ),
                    if (burnt)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 320),
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.scale(scale: 0.85 + 0.15 * Curves.easeOutBack.transform(t), child: child),
                        ),
                        child: Padding(padding: EdgeInsets.symmetric(horizontal: 18 * k), child: panel),
                      ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 14 * k),
        ],
      );
    }
    final banner = mine
        ? (timedOut ? 'Temps écoulé pour $_advName' : '$_advName s’est trompé')
        : (timedOut ? 'Temps écoulé !' : 'Raté !');
    final help = mine ? 'Ta carte revient dans ta main' : 'La carte retourne chez $_advName';
    return Column(
      children: [
        SizedBox(height: 34 * k),
        _opponent(k, mine ? 'récupère… ta carte revient' : 'récupère sa carte'),
        SizedBox(height: 10 * k),
        Expanded(
          child: LayoutBuilder(
            builder: (context, cons) => Center(
              child: CardFace(
                data: data,
                options: options,
                width: _fit(cons, 0.84),
                owner: mine,
                hideBook: !mine,
                footer: mine ? 'Ta carte' : 'Carte de $_advName',
                marks: {
                  for (final o in options)
                    o: (!timedOut && o == choice) ? Mark.wrong : (mine && o == data.answer ? Mark.right : Mark.dim),
                },
                bannerTitle: banner,
                bannerText: help,
              ),
            ),
          ),
        ),
        SizedBox(height: 10 * k),
        continueButton,
        SizedBox(height: 16 * k),
      ],
    );
  }

  // ---- Fin de partie.
  Widget _end(double k) {
    final fin = (_v['fin'] as Map?) ?? const {};
    final won = fin['gagne'] == true;
    final reason = '${fin['raison'] ?? ''}';
    final gain = (fin['gain'] as num?)?.toInt() ?? 0;
    final xp = (fin['xp'] as num?)?.toInt() ?? 0;
    final why = switch (reason) {
      'abandon' => won ? '$_advName a abandonné.' : 'Tu as abandonné.',
      'deconnexion' => won ? '$_advName ne s’est pas reconnecté.' : 'Tu ne t’es pas reconnecté à temps.',
      _ => won ? '$_advName n’a plus de cartes.' : 'Tu n’as plus de cartes.',
    };
    final rematch = (_v['revanche'] as Map?) ?? const {};
    final canRematch = rematch['possible'] == true;
    final waiting = _rematch || rematch['moi'] == true;
    final me = Player.instance.username;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24 * k),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 260 * k,
            height: 180 * k,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (won) OverflowBox(maxWidth: 420 * k, maxHeight: 420 * k, child: GloryRays(size: 420 * k)),
                PlayerAvatar(name: won ? me : _advName, color: won ? playerColors[0] : playerColors[1], size: 120 * k),
              ],
            ),
          ),
          Text(won ? 'Victoire !' : 'Défaite', style: titleStyle(46 * k, won ? Palette.gold : const Color(0xFFFF9B8E))),
          SizedBox(height: 4 * k),
          Text(why, textAlign: TextAlign.center, style: bodyStyle(15 * k, paleText)),
          SizedBox(height: 16 * k),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Gain(text: '${gain >= 0 ? '+' : ''}$gain talents', good: gain >= 0),
              SizedBox(width: 10 * k),
              _Gain(text: '+$xp XP', good: true),
            ],
          ),
          if (fin['etoile'] == true)
            Padding(
              padding: EdgeInsets.only(top: 12 * k),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/aventure/etoile.png', width: 28 * k, height: 28 * k),
                  SizedBox(width: 6 * k),
                  Text('Nouvelle étoile !', style: titleStyle(20 * k, goldLight)),
                ],
              ),
            ),
          SizedBox(height: 28 * k),
          if (canRematch)
            SizedBox(
              width: double.infinity,
              child: GoldButton(
                waiting ? 'En attente de $_advName…' : 'Revanche',
                onPressed: waiting
                    ? null
                    : () {
                        setState(() => _rematch = true);
                        _send(DuelOp.revanche, {'accepte': true});
                      },
                height: 56 * k,
                fontSize: 22 * k,
              ),
            ),
          if (canRematch && rematch['adversaire'] == true && !waiting)
            Padding(
              padding: EdgeInsets.only(top: 8 * k),
              child: Text('$_advName veut une revanche !', style: titleStyle(16 * k, goldLight)),
            ),
          SizedBox(height: 12 * k),
          SizedBox(width: double.infinity, child: NightButton('Retour', onPressed: _quit, height: 52 * k, fontSize: 18 * k)),
        ],
      ),
    );
  }

  Widget _cancelled(double k) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 28 * k),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Partie annulée', style: titleStyle(32 * k, Palette.gold)),
            SizedBox(height: 8 * k),
            Text(
              '${_v['annulation'] ?? ''}'.isEmpty ? 'La partie n’a pas pu commencer.' : '${_v['annulation']}',
              textAlign: TextAlign.center,
              style: bodyStyle(15 * k, paleText),
            ),
            SizedBox(height: 28 * k),
            SizedBox(width: double.infinity, child: NightButton('Retour', onPressed: _quit, height: 52 * k, fontSize: 18 * k)),
          ],
        ),
      );

  Widget _banner(double k, String text) => Positioned(
        left: 16 * k,
        right: 16 * k,
        top: MediaQuery.paddingOf(context).top + 90 * k,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 10 * k),
          decoration: BoxDecoration(
            color: const Color(0xF20D1733),
            borderRadius: BorderRadius.circular(14 * k),
            border: Border.all(color: Palette.gold, width: 1.5),
          ),
          child: Text(text, textAlign: TextAlign.center, style: bodyStyle(14 * k, Palette.cream, weight: 900)),
        ),
      );

  Widget _quitLayer(double k) {
    final over = _step == 'finie' || _step == 'annulee';
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xF006122F),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28 * k),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(over ? 'Quitter ?' : 'Abandonner la partie ?', style: titleStyle(30 * k, Palette.gold)),
              SizedBox(height: 8 * k),
              if (!over)
                Text('Tu perdras ta mise, sans gagner d’XP.', textAlign: TextAlign.center, style: bodyStyle(16 * k, paleText)),
              SizedBox(height: 28 * k),
              SizedBox(
                width: double.infinity,
                child: GoldButton('Continuer la partie', onPressed: () => setState(() => _quitAsked = false), height: 56 * k, fontSize: 21 * k),
              ),
              SizedBox(height: 12 * k),
              SizedBox(
                width: double.infinity,
                child: NightButton(over ? 'Quitter' : 'Abandonner', onPressed: _quit, height: 52 * k, fontSize: 18 * k),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Gain extends StatelessWidget {
  final String text;
  final bool good;

  const _Gain({required this.text, required this.good});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 7 * k),
      decoration: BoxDecoration(
        color: const Color(0xD106122F),
        borderRadius: BorderRadius.circular(18 * k),
        border: Border.all(color: good ? const Color(0x99F2C14E) : const Color(0x99FF9B8E), width: 1.5),
      ),
      child: Text(text, style: titleStyle(17 * k, good ? goldLight : const Color(0xFFFFB4A8))),
    );
  }
}

/// Panneau de la réponse trouvée : réponse, référence, explication.
class _RevealPanel extends StatelessWidget {
  final String title;
  final bool good;
  final CardData data;
  final Widget button;

  const _RevealPanel({required this.title, required this.good, required this.data, required this.button});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Container(
      padding: EdgeInsets.fromLTRB(18 * k, 16 * k, 18 * k, 18 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * k),
        gradient: const RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.2,
          colors: [Color(0xFFFDF3D8), Color(0xFFF6E2B3), Color(0xFFECD09A)],
          stops: [0, 0.6, 1],
        ),
        border: Border.all(color: const Color(0xFFB8862E), width: 3),
        boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(0, 18), blurRadius: 30)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center, style: titleStyle(24 * k, good ? const Color(0xFF2F9E4A) : const Color(0xFF9A3412))),
          SizedBox(height: 2 * k),
          Text(data.answer, textAlign: TextAlign.center, style: titleStyle(22 * k, const Color(0xFF4A2A0E))),
          if (data.reference.isNotEmpty)
            Text(data.reference.toUpperCase(), style: bodyStyle(12 * k, const Color(0xFF8A5A12), weight: 900).copyWith(letterSpacing: 0.5)),
          if (data.explanation.isNotEmpty) ...[
            SizedBox(height: 10 * k),
            Container(
              padding: EdgeInsets.symmetric(vertical: 10 * k, horizontal: 6 * k),
              decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Color(0x598A5A12), width: 1.5))),
              child: Text(
                data.explanation,
                textAlign: TextAlign.center,
                style: bodyStyle(14 * k, Palette.ink, weight: 700).copyWith(fontStyle: FontStyle.italic, height: 1.4),
              ),
            ),
          ],
          SizedBox(height: 14 * k),
          button,
        ],
      ),
    );
  }
}
