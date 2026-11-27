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
import 'card_face.dart';
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
  static const starterTime = 20.0;
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
  double _left = 0;
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
  int _preview = -1;
  CardData? _answerCard;
  List<String> _presented = const [];
  String? _choice;
  AnswerResult? _result;
  bool _timedOut = false;
  int _optionsBefore = 0;
  int _reserveBefore = 0;
  late final AnimationController _burn =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

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
    _burn.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _bank = await _session.bank();
      final pool = _bank.filter(_session.filter);
      final (a, b) = DeckBuilder.deal(pool, _session.history.recentIds, _rng);
      _duel = Duel(a, b, _rng);
      _session.history.record([for (final h in _duel.hands) for (final c in h) c.data.id]);
      if (!mounted) return;
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
    setState(() => _left = max(0, _left - dt));
    if (_left <= 0) {
      _onTimeout = null;
      done();
    }
  }

  void _startTimer(double seconds, VoidCallback onTimeout) {
    _total = seconds;
    _left = seconds;
    _onTimeout = onTimeout;
  }

  void _stopTimer() => _onTimeout = null;

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
    _startTimer(starterTime, () {
      if (_starterChoice != null) return;
      _starterChoice = '';
      _showFlash('Personne n’a répondu.\nNouvelle question.');
      _later(1.6, _showStarter);
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

  void _select(int index) {
    if (_step != _Step.choose) return;
    setState(() => _selected = index);
  }

  void _playSelected() {
    if (_step != _Step.choose || _selected < 0) return;
    final i = _selected;
    _duel.play(i);
    _afterPlay(i, null);
  }

  void _afterPlay(int index, String? message) {
    _stopTimer();
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
      _preview = -1;
      _answerCard = played.data;
      _presented = [..._duel.presented];
      _optionsBefore = played.optionCount;
      _reserveBefore = played.reserve.length;
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
      _preview = -1;
    });
    if (result.correct) _burn.forward(from: 0);
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
        body: Stack(children: [
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
          if (_preview >= 0) _previewLayer(k),
          if (_passTo >= 0) _passLayer(k),
          if (_flash != null) _flashLayer(k),
          if (_quitAsked) _quitLayer(k),
        ]),
      ),
    );
  }

  Widget _body(double k) => switch (_step) {
        _Step.loading => Center(
            child: _error == null
                ? const CircularProgressIndicator(color: Palette.gold)
                : Padding(
                    padding: EdgeInsets.all(28 * k),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: bodyStyle(16 * k, Colors.white)),
                      SizedBox(height: 20 * k),
                      NightButton('Retour', onPressed: () => Navigator.of(context).pop()),
                    ]),
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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_names[p], style: titleStyle(20 * k, Palette.gold)),
            SizedBox(height: 6 * k),
            Container(
              padding: EdgeInsets.fromLTRB(12 * k, 10 * k, 12 * k, 12 * k),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16 * k),
                gradient: const RadialGradient(center: Alignment(0, -0.4), radius: 1.2, colors: [Color(0xFFF8F2E6), Color(0xFFEFE6D4)]),
                border: Border.all(color: const Color(0xFFC9A35A), width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 8))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(round.question.question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Garamond',
                      color: Color(0xFF1D2A4A),
                      fontVariations: [FontVariation('wght', 500)],
                      height: 1.2,
                    ).copyWith(fontSize: 18 * k)),
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
              ]),
            ),
          ]),
        );
    return Column(children: [
      Expanded(child: RotatedBox(quarterTurns: 2, child: half(1))),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 14 * k),
        child: Row(children: [
          Expanded(child: Container(height: 2, color: const Color(0x99F2C14E))),
          SizedBox(width: 10 * k),
          TimerRing(left: _left, total: _total, size: 54 * k),
          SizedBox(width: 10 * k),
          Expanded(child: Container(height: 2, color: const Color(0x99F2C14E))),
        ]),
      ),
      Expanded(child: half(0)),
    ]);
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
    return Column(children: [
      SizedBox(height: 34 * k),
      OpponentRow(name: _names[other], color: playerColors[other], status: '${_duel.hands[other].length} cartes', cards: _duel.hands[other].length, k: k),
      SizedBox(height: 8 * k),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * k),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('À toi, ${_names[poser]}',
                  style: titleStyle(19 * k, Colors.white)
                      .copyWith(shadows: const [Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 6)])),
              Text('Touche une carte pour la voir en grand', style: bodyStyle(12 * k, paleText, weight: 800)),
            ]),
          ),
          SizedBox(width: 10 * k),
          TimerRing(left: _left, total: _total, size: 52 * k),
        ]),
      ),
      SizedBox(height: 8 * k),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final w = _fit(c, 0.74);
          final card = _selected >= 0
              ? CardFace(
                  key: ValueKey(hand[_selected]),
                  data: hand[_selected].data,
                  options: _ownerOptions(hand[_selected]),
                  owner: true,
                  width: w,
                )
              : CardBack(key: const ValueKey('dos'), width: w);
          return Center(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: card));
        }),
      ),
      SizedBox(height: 10 * k),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 70 * k),
        child: GoldButton('Poser cette carte', onPressed: _selected < 0 ? null : _playSelected, height: 46 * k, fontSize: 19 * k),
      ),
      SizedBox(height: 6 * k),
      ClipRect(
        child: HandFan(
          count: hand.length,
          selected: _selected,
          onTap: _select,
          k: k,
          height: 92 * k,
          card: (i, w) => CardFace(data: hand[i].data, options: _ownerOptions(hand[i]), owner: true, width: w),
        ),
      ),
    ]);
  }

  /// Vue du propriétaire : ses propositions dans l'ordre alphabétique (l'ordre ne trahit rien).
  List<String> _ownerOptions(CardInPlay card) => [card.data.answer, ...card.shownWrongs]..sort();

  Widget _cardWithTimer(BoxConstraints c, double w, double k, Widget card) {
    final h = w * cardRatio;
    final left = (c.maxWidth - w) / 2;
    final top = (c.maxHeight - h) / 2;
    final timer = 56 * k;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(left: left, top: top, child: card),
      if (_onTimeout != null)
        Positioned(
          left: min(left + w - timer * 0.55, c.maxWidth - timer - 4 * k),
          top: top - timer * 0.35,
          child: TimerRing(left: _left, total: _total, size: timer),
        ),
    ]);
  }

  // ---- Tu réponds à la carte de l'autre.
  Widget _answerView(double k) {
    final poser = _duel.poser;
    final me = 1 - poser;
    final data = _answerCard!;
    final options = _presented;
    return Column(children: [
      SizedBox(height: 34 * k),
      OpponentRow(name: _names[poser], color: playerColors[poser], status: 'a posé une carte', cards: _duel.hands[poser].length, k: k),
      SizedBox(height: 10 * k),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
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
        }),
      ),
      SizedBox(height: 8 * k),
      Instruction('Touche la bonne réponse', k: k),
      _peekHand(me, k),
    ]);
  }

  Map<String, Mark> _answerMarks(CardData data, List<String> options) {
    final choice = _choice;
    if (choice == null) return const {};
    final right = choice == data.answer;
    return {for (final o in options) o: o == choice ? (right ? Mark.right : Mark.wrong) : Mark.dim};
  }

  /// Ta main, visible au bas de l'écran ; on touche une carte pour la relire en grand.
  Widget _peekHand(int player, double k) {
    final hand = _duel.hands[player];
    return SizedBox(
      height: 58 * k,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: 120 * k,
          child: HandFan(
            count: hand.length,
            k: k,
            height: 120 * k,
            onTap: (i) => setState(() => _preview = i),
            card: (i, w) => CardFace(data: hand[i].data, options: _ownerOptions(hand[i]), owner: true, width: w),
          ),
        ),
      ),
    );
  }

  Widget _previewLayer(double k) {
    final player = _step == _Step.answer ? 1 - _duel.poser : _duel.poser;
    final hand = _duel.hands[player];
    if (_preview >= hand.length) return const SizedBox.shrink();
    final card = hand[_preview];
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _preview = -1),
        child: ColoredBox(
          color: const Color(0xD906122F),
          child: SafeArea(
            child: Column(children: [
              SizedBox(height: 20 * k),
              Instruction('Ta carte', help: 'Touche l’écran pour revenir', k: k),
              SizedBox(height: 10 * k),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: CardFace(data: card.data, options: _ownerOptions(card), owner: true, width: _fit(c, 0.84)),
                  ),
                ),
              ),
              SizedBox(height: 20 * k),
            ]),
          ),
        ),
      ),
    );
  }

  // ---- Résultat.
  Widget _resultView(double k) {
    final result = _result!;
    final owner = result.owner;
    final data = result.card.data;
    if (result.correct) {
      return Column(children: [
        SizedBox(height: 34 * k),
        OpponentRow(name: _names[owner], color: playerColors[owner], status: '${_duel.hands[owner].length} cartes', cards: _duel.hands[owner].length, k: k),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = _fit(c, 0.5);
            return AnimatedBuilder(
              animation: _burn,
              builder: (context, _) => _burning(c, w, k, data, _presented),
            );
          }),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18 * k),
          child: _revealPanel(k, data),
        ),
        SizedBox(height: 14 * k),
      ]);
    }
    final options = _presented;
    final now = result.card.optionCount;
    final help = now < _optionsBefore
        ? 'avec $now propositions'
        : (result.card.reserve.length < _reserveBefore ? 'toujours 2 propositions, dont une nouvelle' : 'toujours avec 2 propositions');
    return Column(children: [
      SizedBox(height: 34 * k),
      OpponentRow(name: _names[owner], color: playerColors[owner], status: 'récupère sa carte', cards: _duel.hands[owner].length, k: k),
      SizedBox(height: 10 * k),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final w = _fit(c, 0.84);
          return Center(
            child: CardFace(
              data: data,
              options: options,
              width: w,
              hideBook: true,
              footer: 'Carte de ${_names[owner]}',
              marks: {
                for (final o in options) o: (!_timedOut && o == _choice) ? Mark.wrong : Mark.dim,
              },
              bannerTitle: _timedOut ? 'Temps écoulé !' : 'Raté !',
              bannerText: 'La carte retourne chez ${_names[owner]}',
            ),
          );
        }),
      ),
      SizedBox(height: 8 * k),
      Instruction('${_names[owner]} pourra te la renvoyer', help: help, k: k),
      SizedBox(height: 10 * k),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 70 * k),
        child: GoldButton('Continuer', onPressed: _continue, height: 46 * k, fontSize: 19 * k),
      ),
      SizedBox(height: 16 * k),
    ]);
  }

  /// La carte trouvée brûle : halo doré, tampon « DÉTRUITE », puis elle se consume.
  Widget _burning(BoxConstraints c, double w, double k, CardData data, List<String> options) {
    final t = _burn.value;
    final fade = Curves.easeIn.transform(((t - 0.45) / 0.55).clamp(0, 1));
    final glow = sin(min(t, 1) * pi) * 0.9 + 0.1;
    final stamp = Curves.easeOutBack.transform((t / 0.3).clamp(0, 1));
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: w * 1.9,
        height: w * 1.9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            Color.fromRGBO(255, 236, 170, 0.9 * glow),
            Color.fromRGBO(255, 190, 70, 0.35 * glow),
            const Color(0x00FFAA28),
          ], stops: const [0, 0.35, 0.7]),
        ),
      ),
      Opacity(
        opacity: 1 - fade,
        child: Transform.rotate(
          angle: -4 * pi / 180,
          child: Transform.scale(
            scale: 1 - 0.15 * fade,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Color.fromRGBO(255, 170, 60, 0.55 * fade), BlendMode.srcATop),
              child: CardFace(
                data: data,
                options: options,
                width: w,
                marks: {data.answer: Mark.right},
                footer: 'Carte de ${_names[_result!.owner]}',
              ),
            ),
          ),
        ),
      ),
      for (var i = 0; i < 8; i++)
        Transform.translate(
          offset: Offset(cos(i * 0.8 + t * 3) * w * (0.55 + 0.2 * t), sin(i * 1.3 + t * 2) * w * (0.8 + 0.2 * t)),
          child: Container(
            width: 5 * k,
            height: 5 * k,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFE9A8),
              boxShadow: [BoxShadow(color: Color(0xE6FFC85A), blurRadius: 6, spreadRadius: 2)],
            ),
          ),
        ),
      Opacity(
        opacity: (1 - fade * 0.3).clamp(0, 1) * min(1, t / 0.15),
        child: Transform.rotate(
          angle: -12 * pi / 180,
          child: Transform.scale(
            scale: 1.6 - 0.6 * stamp,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 4 * k),
              decoration: BoxDecoration(
                color: const Color(0x8CB87814),
                borderRadius: BorderRadius.circular(8 * k),
                border: Border.all(color: goldLight, width: 3 * k),
                boxShadow: const [BoxShadow(color: Color(0xB3FFD66E), blurRadius: 24)],
              ),
              child: Text('DÉTRUITE',
                  style: titleStyle(22 * k, const Color(0xFFFFF3C4))
                      .copyWith(letterSpacing: 1, shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 4)])),
            ),
          ),
        ),
      ),
    ]);
  }

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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Bonne réponse !', style: titleStyle(26 * k, const Color(0xFF2F9E4A))),
          SizedBox(height: 2 * k),
          Text(data.answer, textAlign: TextAlign.center, style: titleStyle(22 * k, const Color(0xFF4A2A0E))),
          SizedBox(height: 2 * k),
          Text(data.reference.toUpperCase(), style: bodyStyle(12 * k, const Color(0xFF8A5A12), weight: 900).copyWith(letterSpacing: 0.5)),
          if (data.explanation.isNotEmpty) ...[
            SizedBox(height: 10 * k),
            Container(
              padding: EdgeInsets.symmetric(vertical: 10 * k, horizontal: 6 * k),
              decoration: const BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: Color(0x598A5A12), width: 1.5)),
              ),
              child: Text(data.explanation,
                  textAlign: TextAlign.center,
                  style: bodyStyle(14 * k, Palette.ink, weight: 700).copyWith(fontStyle: FontStyle.italic, height: 1.4)),
            ),
          ],
          SizedBox(height: 14 * k),
          GoldButton('Continuer', onPressed: _continue, height: 46 * k, fontSize: 19 * k),
        ]),
      );

  // ---- Fin.
  Widget _endView(double k) {
    final w = _duel.winner;
    final l = _duel.loser;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24 * k),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        PlayerAvatar(name: _names[w], color: playerColors[w], size: 110 * k),
        SizedBox(height: 12 * k),
        Text(_names[w],
            textAlign: TextAlign.center,
            style: titleStyle(44 * k, Palette.gold).copyWith(shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 4))])),
        Text('remporte la partie !', style: titleStyle(24 * k, Palette.cream)),
        SizedBox(height: 8 * k),
        Text('${_names[l]} n’a plus de cartes. Il en reste ${_duel.hands[w].length} à ${_names[w]}.',
            textAlign: TextAlign.center, style: bodyStyle(15 * k, paleText)),
        SizedBox(height: 30 * k),
        SizedBox(
          width: double.infinity,
          child: GoldButton('Rejouer',
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LocalMatchScreen())),
              height: 56 * k,
              fontSize: 22 * k),
        ),
        SizedBox(height: 12 * k),
        SizedBox(
          width: double.infinity,
          child: NightButton('Retour au menu', onPressed: () => Navigator.of(context).pop(), height: 52 * k, fontSize: 18 * k),
        ),
      ]),
    );
  }

  // ---- Calques.
  Widget _passLayer(double k) => Positioned.fill(
        child: Stack(fit: StackFit.expand, children: [
          const GameBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28 * k),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                  child: GoldButton('Je suis ${_names[_passTo]}', onPressed: _passDone, height: 60 * k, fontSize: 22 * k),
                ),
              ]),
            ),
          ),
        ]),
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
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Quitter la partie ?', style: titleStyle(32 * k, Palette.gold)),
              SizedBox(height: 8 * k),
              Text('La partie en cours sera perdue.', style: bodyStyle(16 * k, paleText)),
              SizedBox(height: 28 * k),
              SizedBox(width: double.infinity, child: GoldButton('Continuer la partie', onPressed: _resume, height: 56 * k, fontSize: 21 * k)),
              SizedBox(height: 12 * k),
              SizedBox(
                width: double.infinity,
                child: NightButton('Quitter', onPressed: () => Navigator.of(context).pop(), height: 52 * k, fontSize: 18 * k),
              ),
            ]),
          ),
        ),
      );
}

