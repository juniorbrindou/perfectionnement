import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/card_data.dart';
import '../../core/card_in_play.dart';
import '../../core/deck_builder.dart';
import '../../core/duel.dart';
import '../../core/question_bank.dart';
import '../../core/starter_question.dart';
import '../../core/rand.dart';
import '../../state/session.dart';
import '../theme.dart';
import 'burn.dart';
import 'card_face.dart';
import 'celebration.dart';
import 'table.dart';

/// Partie à deux sur le même téléphone (PRD §2 et §3.2), maquette « Table de jeu ».
///
/// Question de départ en écran partagé → le poseur choisit une carte de sa main, ouverte
/// devant lui → « Passe le téléphone » → l'autre répond sur la carte → résultat : bonne
/// réponse, la carte brûle ; mauvaise, elle retourne chez son propriétaire avec une
/// proposition de moins. Celui qui vient de répondre pose à son tour.
class LocalMatchScreen extends StatefulWidget {
  /// Hasard imposé (tests) ; sinon tiré au sort.
  final Random? rng;

  const LocalMatchScreen({super.key, this.rng});

  @override
  State<LocalMatchScreen> createState() => _LocalMatchScreenState();
}

enum _Step { loading, starter, choose, answer, result, end }

class _LocalMatchScreenState extends State<LocalMatchScreen> with TickerProviderStateMixin {
  static const chooseTime = 20.0;
  static const answerTime = 30.0;

  late final Random _rng = widget.rng ?? Random();
  final _session = Session.instance;
  late final List<String> _names = [..._session.playerNames];

  late QuestionBank _bank;
  late Duel _duel;
  _Step _step = _Step.loading;
  String? _error;

  // Minuteur
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Temps restant : seul le minuteur se redessine à chaque image, pas tout l’écran.
  final _clock = ValueNotifier<double>(0);
  double _total = 1;
  VoidCallback? _onTimeout;
  bool _paused = false;

  // Question de départ
  final List<StarterQuestion> _starterQueue = [];
  StarterRound? _starter;
  int _starterPlayer = -1;
  String? _starterChoice;

  // Passage du téléphone
  int _passTo = -1;
  String _passText = '';
  VoidCallback? _afterPass;

  // Choix et réponse
  int _selected = -1;
  CardData? _answerCard;
  List<String> _presented = const [];
  String? _choice;
  AnswerResult? _result;
  bool _timedOut = false;

  /// La carte trouvée a fini de brûler : le panneau de la réponse s'affiche.
  bool _panelShown = false;

  String? _flash;
  bool _quitAsked = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _bank = await _session.bank();
      final pool = _bank.filter(_session.filter);
      final (a, b) = DeckBuilder.deal(pool, _session.history.recentIds, _rng);
      _duel = Duel(a, b, _rng);
      _session.history.record([
        for (final h in _duel.hands)
          for (final c in h) c.data.id,
      ]);
      if (!mounted) return;
      _precacheHand(0);
      _precacheHand(1);
      _showStarter();
    } catch (e) {
      if (mounted) setState(() => _error = 'Pas assez de cartes pour ${_session.filter.describe()}.');
    }
  }

  // ------------------------------------------------------------ Minuteur

  void _tick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final done = _onTimeout;
    if (done == null || _paused || _passTo >= 0) return;
    _clock.value = max(0, _clock.value - dt);
    if (_clock.value <= 0) {
      _onTimeout = null;
      done();
    }
  }

  void _startTimer(double seconds, VoidCallback onTimeout) {
    _total = seconds;
    _clock.value = seconds;
    _onTimeout = onTimeout;
  }

  void _stopTimer() => _onTimeout = null;

  Widget _timer(double size) => ValueListenableBuilder<double>(
    valueListenable: _clock,
    builder: (context, left, _) => TimerRing(left: left, total: _total, size: size),
  );

  void _later(double seconds, VoidCallback then) =>
      Future.delayed(Duration(milliseconds: (seconds * 1000).round()), () {
        if (mounted) then();
      });

  void _showFlash(String text) {
    setState(() => _flash = text);
    _later(2.0, () {
      if (_flash == text) setState(() => _flash = null);
    });
  }

  // ------------------------------------------------------------ Question de départ

  void _showStarter() {
    if (_starterQueue.isEmpty) {
      _starterQueue.addAll(_bank.starters);
      shuffleWith(_starterQueue, _rng);
    }
    setState(() {
      _step = _Step.starter;
      _starter = StarterRound(_starterQueue.removeLast(), _rng);
      _starterPlayer = -1;
      _starterChoice = null;
    });
  }

  void _onStarterAnswer(int player, String choice) {
    final round = _starter!;
    if (_starterChoice != null) return;
    _stopTimer();
    setState(() {
      _starterPlayer = player;
      _starterChoice = choice;
    });
    final first = round.resolve(player, choice);
    final msg = first == player ? '${_names[player]} a trouvé !' : 'Mauvaise réponse de ${_names[player]}.';
    _showFlash('$msg\n${_names[first]} commence.');
    _later(2.2, () {
      _duel.startWith(first);
      _pass(first, 'Tu commences : choisis la carte à poser.', _beginChoose);
    });
  }

  // ------------------------------------------------------------ Passage du téléphone

  void _pass(int player, String text, VoidCallback next) {
    _stopTimer();
    setState(() {
      _passTo = player;
      _passText = text;
      _afterPass = next;
    });
  }

  void _passDone() {
    final next = _afterPass;
    setState(() {
      _passTo = -1;
      _afterPass = null;
    });
    next?.call();
  }

  // ------------------------------------------------------------ Choisir la carte à poser

  void _beginChoose() {
    _precacheHand(_duel.poser);
    setState(() {
      _step = _Step.choose;
      _selected = -1;
      _choice = null;
      _result = null;
    });
    _startTimer(chooseTime, () {
      final i = _duel.playRandom();
      _afterPlay(i, 'Temps écoulé : une carte a été posée au hasard.');
    });
  }

  /// Décode d'avance les illustrations de la main : la carte touchée s'affiche aussitôt.
  void _precacheHand(int player) {
    for (final c in _duel.hands[player]) {
      final art = _session.illustration(c.data.books);
      if (art != null) precacheImage(AssetImage(art), context);
    }
  }

  void _select(int index) {
    if (_step != _Step.choose || _duel.phase != Phase.choosing) return;
    setState(() => _selected = index);
  }

  void _playSelected() {
    if (_step != _Step.choose || _selected < 0 || _duel.phase != Phase.choosing) return;
    final i = _selected;
    _duel.play(i);
    _afterPlay(i, null);
  }

  void _afterPlay(int index, String? message) {
    _stopTimer();
    // La carte a quitté la main : plus rien n’y est choisi (sinon l’indice dépasse la main).
    setState(() => _selected = -1);
    if (message != null) _showFlash(message);
    _later(message == null ? 0.3 : 2.2, () {
      _pass(_duel.answerer, '${_names[_duel.poser]} te pose une question.', _beginAnswer);
    });
  }

  // ------------------------------------------------------------ Répondre sur la carte

  void _beginAnswer() {
    final played = _duel.played!;
    setState(() {
      _step = _Step.answer;
      _choice = null;
      _answerCard = played.data;
      _presented = [..._duel.presented];
    });
    _startTimer(answerTime, () {
      if (_step != _Step.answer || _choice != null) return;
      _timedOut = true;
      _showResult(_duel.answerTimeout());
    });
  }

  void _onAnswer(String choice) {
    if (_step != _Step.answer || _choice != null) return;
    _stopTimer();
    setState(() => _choice = choice);
    final result = _duel.answer(choice);
    _later(0.8, () {
      _timedOut = false;
      _showResult(result);
    });
  }

  void _showResult(AnswerResult result) {
    _stopTimer();
    setState(() {
      _step = _Step.result;
      _result = result;
      _panelShown = false;
    });
  }

  void _continue() {
    if (_duel.phase == Phase.finished) {
      setState(() => _step = _Step.end);
    } else {
      _beginChoose();
    }
  }

  // ------------------------------------------------------------ Quitter

  void _askQuit() => setState(() {
    _quitAsked = true;
    _paused = true;
  });

  void _resume() => setState(() {
    _quitAsked = false;
    _paused = false;
  });

  // ------------------------------------------------------------ Affichage

  String? get _art => switch (_step) {
    _Step.choose when _selected >= 0 => _session.illustration(_duel.hands[_duel.poser][_selected].data.books),
    _Step.result when _result!.correct => _session.illustration(_result!.card.data.books),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quitAsked ? _resume() : _askQuit();
      },
      child: Scaffold(
        backgroundColor: Palette.night,
        body: Stack(
          children: [
            Positioned.fill(child: GameBackground(art: _step == _Step.loading ? null : _art)),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: pad.top + 6 * k, bottom: pad.bottom),
                child: _body(k),
              ),
            ),
            if (_step != _Step.end && _step != _Step.loading)
              Positioned(
                left: 8 * k,
                top: pad.top + 2 * k,
                child: IconButton(
                  onPressed: _askQuit,
                  icon: Icon(Icons.close_rounded, color: Colors.white70, size: 22 * k),
                ),
              ),
            if (_passTo >= 0) _passLayer(k),
            if (_step == _Step.end) const Positioned.fill(child: Celebration()),
            if (_flash != null) _flashLayer(k),
            if (_quitAsked) _quitLayer(k),
          ],
        ),
      ),
    );
  }

  Widget _body(double k) => switch (_step) {
    _Step.loading => Center(
      child: _error == null
          ? const CircularProgressIndicator(color: Palette.gold)
          : Padding(
              padding: EdgeInsets.all(28 * k),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: bodyStyle(16 * k, Colors.white)),
                  SizedBox(height: 20 * k),
                  NightButton('Retour', onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
    ),
    _Step.starter => _starterView(k),
    _Step.choose => _chooseView(k),
    _Step.answer => _answerView(k),
    _Step.result => _resultView(k),
    _Step.end => _endView(k),
  };

  /// Largeur de la plus grande carte qui tient dans la boîte.
  double _fit(BoxConstraints c, double maxShare) => min(c.maxWidth * maxShare, c.maxHeight / cardRatio);

  // ---- Question de départ : écran partagé, le joueur 2 en haut, retourné.
  Widget _starterView(double k) {
    final round = _starter!;
    Widget half(int p) => Padding(
      padding: EdgeInsets.fromLTRB(16 * k, 10 * k, 16 * k, 10 * k),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_names[p], style: titleStyle(20 * k, Palette.gold)),
          SizedBox(height: 6 * k),
          Container(
            padding: EdgeInsets.fromLTRB(12 * k, 10 * k, 12 * k, 12 * k),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16 * k),
              gradient: const RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.2,
                colors: [Color(0xFFF8F2E6), Color(0xFFEFE6D4)],
              ),
              border: Border.all(color: const Color(0xFFC9A35A), width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  round.question.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Garamond',
                    color: Color(0xFF1D2A4A),
                    fontVariations: [FontVariation('wght', 500)],
                    height: 1.2,
                  ).copyWith(fontSize: 18 * k),
                ),
                SizedBox(height: 8 * k),
                for (var i = 0; i < round.options.length; i++) ...[
                  if (i > 0) SizedBox(height: 5 * k),
                  AnswerPill(
                    u: 3.2 * k,
                    letter: letters[i],
                    text: round.options[i],
                    mark: _starterMark(p, round.options[i]),
                    onTap: () => _onStarterAnswer(p, round.options[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        // Place pour la croix de fermeture, au-dessus de la moitié retournée.
        SizedBox(height: 40 * k),
        Expanded(child: RotatedBox(quarterTurns: 2, child: half(1))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * k),
          child: Row(
            children: [
              Expanded(child: Container(height: 2, color: const Color(0x99F2C14E))),
              SizedBox(width: 10 * k),
              // Pas de délai : la première bonne réponse décide qui commence.
              Transform.rotate(
                angle: pi / 4,
                child: Container(width: 10 * k, height: 10 * k, color: const Color(0xFFF2C14E)),
              ),
              SizedBox(width: 10 * k),
              Expanded(child: Container(height: 2, color: const Color(0x99F2C14E))),
            ],
          ),
        ),
        Expanded(child: half(0)),
      ],
    );
  }

  Mark _starterMark(int half, String option) {
    final choice = _starterChoice;
    if (choice == null || choice.isEmpty) return Mark.none;
    if (option == _starter!.question.answer) return Mark.right;
    if (half == _starterPlayer && option == choice) return Mark.wrong;
    return Mark.dim;
  }

  // ---- Ton tour : ta main ouverte, la carte touchée en grand.
  Widget _chooseView(double k) {
    final poser = _duel.poser;
    final other = 1 - poser;
    final hand = _duel.hands[poser];
    return Column(
      children: [
        SizedBox(height: 34 * k),
        OpponentRow(
          name: _names[other],
          color: playerColors[other],
          status: '${_duel.hands[other].length} cartes',
          cards: _duel.hands[other].length,
          k: k,
        ),
        SizedBox(height: 8 * k),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16 * k),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choisis une question à poser à ${_names[other]}',
                      style: titleStyle(17 * k, Colors.white).copyWith(
                        shadows: const [Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 6)],
                      ),
                    ),
                    Text('Touche une carte pour la voir en grand', style: bodyStyle(11 * k, paleText, weight: 800)),
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
              final card = _selected >= 0
                  ? CardFace(
                      key: ValueKey(hand[_selected]),
                      data: hand[_selected].data,
                      options: _ownerOptions(hand[_selected]),
                      owner: true,
                      width: w,
                    )
                  : CardBack(key: const ValueKey('dos'), width: w * cardRatio / backRatio);
              return Center(
                child: AnimatedSwitcher(duration: const Duration(milliseconds: 120), child: card),
              );
            },
          ),
        ),
        SizedBox(height: 10 * k),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 70 * k),
          child: GoldButton(
            'Poser cette carte',
            onPressed: _selected < 0 ? null : _playSelected,
            height: 42 * k,
            fontSize: 19 * k,
          ),
        ),
        SizedBox(height: 8 * k),
        // La main entière, bien visible : les cartes ne sont pas coupées par le bas de l'écran.
        HandFan(
          count: hand.length,
          selected: _selected,
          onTap: _select,
          k: k,
          height: 120 * k,
          card: (i, w) => CardFace(data: hand[i].data, options: _ownerOptions(hand[i]), owner: true, width: w),
        ),
        SizedBox(height: 4 * k),
      ],
    );
  }

  /// Vue du propriétaire : ses propositions dans l'ordre alphabétique (l'ordre ne trahit rien).
  List<String> _ownerOptions(CardInPlay card) => [card.data.answer, ...card.shownWrongs]..sort();

  Widget _cardWithTimer(BoxConstraints c, double w, double k, Widget card) {
    final h = w * cardRatio;
    final left = (c.maxWidth - w) / 2;
    final top = (c.maxHeight - h) / 2;
    final timer = 56 * k;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: left, top: top, child: card),
        if (_onTimeout != null)
          Positioned(
            left: min(left + w - timer * 0.55, c.maxWidth - timer - 4 * k),
            top: top - timer * 0.35,
            child: _timer(timer),
          ),
      ],
    );
  }

  // ---- Tu réponds à la carte de l'autre.
  Widget _answerView(double k) {
    final poser = _duel.poser;
    final me = 1 - poser;
    final data = _answerCard!;
    final options = _presented;
    return Column(
      children: [
        SizedBox(height: 34 * k),
        OpponentRow(
          name: _names[poser],
          color: playerColors[poser],
          status: 'a posé une carte',
          cards: _duel.hands[poser].length,
          k: k,
        ),
        SizedBox(height: 10 * k),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = _fit(c, 0.84);
              return _cardWithTimer(
                c,
                w,
                k,
                CardFace(
                  data: data,
                  options: options,
                  width: w,
                  hideBook: true,
                  footer: 'Carte de ${_names[poser]}',
                  marks: _answerMarks(data, options),
                  onAnswer: _choice == null ? _onAnswer : null,
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8 * k),
        Instruction('Touche la bonne réponse', k: k),
        _peekHand(me, k),
      ],
    );
  }

  Map<String, Mark> _answerMarks(CardData data, List<String> options) {
    final choice = _choice;
    if (choice == null) return const {};
    final right = choice == data.answer;
    return {for (final o in options) o: o == choice ? (right ? Mark.right : Mark.wrong) : Mark.dim};
  }

  /// Ta main, visible en miniatures au bas de l'écran : on ne l'agrandit que pour poser une carte.
  Widget _peekHand(int player, double k) {
    final hand = _duel.hands[player];
    // Ta main en petit (moitié de taille) : un rappel, la carte à laquelle on répond prime.
    return Padding(
      padding: EdgeInsets.only(top: 4 * k, bottom: 4 * k),
      child: HandFan(
        count: hand.length,
        k: k,
        height: 60 * k,
        scale: 0.5,
        card: (i, w) => CardFace(data: hand[i].data, options: _ownerOptions(hand[i]), owner: true, width: w),
      ),
    );
  }

  // ---- Résultat.
  Widget _resultView(double k) {
    final result = _result!;
    final owner = result.owner;
    final data = result.card.data;
    if (result.correct) {
      return Column(
        children: [
          SizedBox(height: 34 * k),
          OpponentRow(
            name: _names[owner],
            color: playerColors[owner],
            status: '${_duel.hands[owner].length} cartes',
            cards: _duel.hands[owner].length,
            k: k,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = _fit(c, 0.8);
                return _burning(w, k, data, _presented);
              },
            ),
          ),
          SizedBox(height: 14 * k),
        ],
      );
    }
    final options = _presented;
    return Column(
      children: [
        SizedBox(height: 34 * k),
        OpponentRow(
          name: _names[owner],
          color: playerColors[owner],
          status: 'récupère sa carte',
          cards: _duel.hands[owner].length,
          k: k,
        ),
        SizedBox(height: 10 * k),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = _fit(c, 0.84);
              return Center(
                child: CardFace(
                  data: data,
                  options: options,
                  width: w,
                  hideBook: true,
                  footer: 'Carte de ${_names[owner]}',
                  marks: {for (final o in options) o: (!_timedOut && o == _choice) ? Mark.wrong : Mark.dim},
                  bannerTitle: _timedOut ? 'Temps écoulé !' : 'Raté !',
                  bannerText: 'La carte retourne chez ${_names[owner]}',
                ),
              );
            },
          ),
        ),
        SizedBox(height: 10 * k),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 70 * k),
          child: GoldButton('Continuer', onPressed: _continue, height: 46 * k, fontSize: 19 * k),
        ),
        SizedBox(height: 16 * k),
      ],
    );
  }

  /// La carte trouvée brûle au feu doré, puis le panneau de la réponse apparaît au centre.
  Widget _burning(double w, double k, CardData data, List<String> options) => Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      FeuDore(
        key: ValueKey(_result),
        size: Size(w, w * cardRatio),
        onConsumed: () {
          if (mounted) setState(() => _panelShown = true);
        },
        child: CardFace(
          data: data,
          options: options,
          width: w,
          marks: {data.answer: Mark.right},
          footer: 'Carte de ${_names[_result!.owner]}',
        ),
      ),
      if (_panelShown)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.85 + 0.15 * Curves.easeOutBack.transform(t), child: child),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18 * k),
            child: _revealPanel(k, data),
          ),
        ),
    ],
  );

  Widget _revealPanel(double k, CardData data) => Container(
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
        Text('Bonne réponse !', style: titleStyle(26 * k, const Color(0xFF2F9E4A))),
        SizedBox(height: 2 * k),
        Text(data.answer, textAlign: TextAlign.center, style: titleStyle(22 * k, const Color(0xFF4A2A0E))),
        SizedBox(height: 2 * k),
        Text(
          data.reference.toUpperCase(),
          style: bodyStyle(12 * k, const Color(0xFF8A5A12), weight: 900).copyWith(letterSpacing: 0.5),
        ),
        if (data.explanation.isNotEmpty) ...[
          SizedBox(height: 10 * k),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10 * k, horizontal: 6 * k),
            decoration: const BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: Color(0x598A5A12), width: 1.5)),
            ),
            child: Text(
              data.explanation,
              textAlign: TextAlign.center,
              style: bodyStyle(14 * k, Palette.ink, weight: 700).copyWith(fontStyle: FontStyle.italic, height: 1.4),
            ),
          ),
        ],
        SizedBox(height: 14 * k),
        GoldButton('Continuer', onPressed: _continue, height: 46 * k, fontSize: 19 * k),
      ],
    ),
  );

  // ---- Fin.
  /// Victoire : le gagnant arrive dans des rayons dorés, puis le texte et les boutons
  /// (la fête, confettis et feux d'artifice, est posée par-dessus l'écran : voir build).
  Widget _endView(double k) {
    final w = _duel.winner;
    final l = _duel.loser;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) {
        double phase(double a, double b, [Curve curve = Curves.easeOut]) =>
            curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
        Widget rise(double a, double b, Widget child) {
          final p = phase(a, b);
          return Opacity(
            opacity: p,
            child: Transform.translate(offset: Offset(0, 24 * k * (1 - p)), child: child),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * k),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 260 * k,
                height: 200 * k,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: phase(0.15, 0.5),
                      child: OverflowBox(
                        maxWidth: 420 * k,
                        maxHeight: 420 * k,
                        child: GloryRays(size: 420 * k),
                      ),
                    ),
                    Transform.scale(
                      scale: phase(0, 0.45, Curves.elasticOut),
                      child: PlayerAvatar(name: _names[w], color: playerColors[w], size: 130 * k),
                    ),
                  ],
                ),
              ),
              rise(
                0.3,
                0.6,
                Text(
                  _names[w],
                  textAlign: TextAlign.center,
                  style: titleStyle(46 * k, Palette.gold).copyWith(
                    shadows: const [
                      Shadow(color: Color(0x99000000), offset: Offset(0, 4)),
                      Shadow(color: Color(0x88F6C24A), blurRadius: 24),
                    ],
                  ),
                ),
              ),
              rise(0.4, 0.7, Text('remporte la partie !', style: titleStyle(26 * k, Palette.cream))),
              SizedBox(height: 8 * k),
              rise(
                0.5,
                0.8,
                Text(
                  '${_names[l]} n’a plus de cartes. Il en reste ${_duel.hands[w].length} à ${_names[w]}.',
                  textAlign: TextAlign.center,
                  style: bodyStyle(15 * k, paleText),
                ),
              ),
              SizedBox(height: 30 * k),
              rise(
                0.7,
                1,
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: GoldButton(
                        'Rejouer',
                        onPressed: () => Navigator.of(
                          context,
                        ).pushReplacement(MaterialPageRoute(builder: (_) => const LocalMatchScreen())),
                        height: 56 * k,
                        fontSize: 22 * k,
                      ),
                    ),
                    SizedBox(height: 12 * k),
                    SizedBox(
                      width: double.infinity,
                      child: NightButton(
                        'Retour au menu',
                        onPressed: () => Navigator.of(context).pop(),
                        height: 52 * k,
                        fontSize: 18 * k,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Calques.
  Widget _passLayer(double k) => Positioned.fill(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const GameBackground(),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28 * k),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Passe le téléphone à', style: bodyStyle(18 * k, paleText)),
                SizedBox(height: 14 * k),
                PlayerAvatar(name: _names[_passTo], color: playerColors[_passTo], size: 96 * k),
                SizedBox(height: 10 * k),
                Text(_names[_passTo], textAlign: TextAlign.center, style: titleStyle(44 * k, Palette.gold)),
                SizedBox(height: 6 * k),
                Text(_passText, textAlign: TextAlign.center, style: bodyStyle(16 * k, Palette.cream)),
                SizedBox(height: 40 * k),
                SizedBox(
                  width: double.infinity,
                  child: GoldButton(
                    'Je suis ${_names[_passTo]}',
                    onPressed: _passDone,
                    height: 60 * k,
                    fontSize: 22 * k,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _flashLayer(double k) => Positioned(
    left: 22 * k,
    right: 22 * k,
    top: 0,
    bottom: 0,
    child: IgnorePointer(
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18 * k, vertical: 14 * k),
          decoration: BoxDecoration(
            color: const Color(0xF20D1733),
            borderRadius: BorderRadius.circular(18 * k),
            border: Border.all(color: const Color(0xFFF2C14E), width: 2.5),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 20)],
          ),
          child: Text(_flash!, textAlign: TextAlign.center, style: titleStyle(20 * k, Palette.cream)),
        ),
      ),
    ),
  );

  Widget _quitLayer(double k) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0xF006122F),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28 * k),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Quitter la partie ?', style: titleStyle(32 * k, Palette.gold)),
            SizedBox(height: 8 * k),
            Text('La partie en cours sera perdue.', style: bodyStyle(16 * k, paleText)),
            SizedBox(height: 28 * k),
            SizedBox(
              width: double.infinity,
              child: GoldButton('Continuer la partie', onPressed: _resume, height: 56 * k, fontSize: 21 * k),
            ),
            SizedBox(height: 12 * k),
            SizedBox(
              width: double.infinity,
              child: NightButton(
                'Quitter',
                onPressed: () => Navigator.of(context).pop(),
                height: 52 * k,
                fontSize: 18 * k,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
