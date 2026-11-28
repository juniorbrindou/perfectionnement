import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../state/online.dart';
import '../../state/quiz.dart';
import '../../state/session.dart';
import '../../state/sound.dart';
import '../game/celebration.dart';
import '../game/pictos.dart';
import '../game/table.dart';
import '../theme.dart';
import '../toast.dart';

const _parchment = Color(0xFFF7EEDB);
const _ink = Color(0xFF2C2216);
const _good = Color(0xFF2F8A3A);
const _bad = Color(0xFFB63A3A);

/// Aventure en quiz : le Scribe pose les questions de l'étape une par une. Après chaque réponse, on
/// voit la bonne réponse et sa référence ; à la fin, les étoiles et les gains.
class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final QuizQuestion first;
  final String levelName;

  const QuizScreen({super.key, required this.quiz, required this.first, required this.levelName});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  late QuizQuestion _question = widget.first;
  QuizAnswer? _answer;
  String? _picked;
  bool _busy = false;
  QuizEnd? _end;

  /// Résultat de chaque question déjà jouée (vrai : trouvée).
  final List<bool> _results = [];

  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  DateTime _askedAt = DateTime.now();
  int _ticked = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _tick())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  double get _total => max(1, _question.seconds).toDouble();

  void _tick() {
    if (_answer != null || _end != null || _busy) return;
    final left = max(0.0, _question.seconds - DateTime.now().difference(_askedAt).inMilliseconds / 1000);
    _clock.value = left;
    final second = left.ceil();
    if (second >= 1 && second <= 5 && second != _ticked) {
      _ticked = second;
      Sound.instance.play('tic', volume: 0.6);
    }
    if (left <= 0) _reply('');
  }

  Future<void> _reply(String choice) async {
    if (_busy || _answer != null) return;
    setState(() {
      _busy = true;
      _picked = choice;
    });
    try {
      final a = await widget.quiz.answer(choice);
      if (!mounted) return;
      Sound.instance.play(a.correct ? 'juste' : 'faux');
      setState(() {
        _answer = a;
        _results.add(a.correct);
      });
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    final a = _answer;
    if (a == null || _busy) return;
    if (a.end != null) {
      Sound.instance.play(a.end!.stars > 0 ? 'victoire' : 'defaite');
      setState(() => _end = a.end);
      return;
    }
    setState(() => _busy = true);
    try {
      final q = await widget.quiz.next();
      if (!mounted) return;
      setState(() {
        _question = q;
        _answer = null;
        _picked = null;
        _askedAt = DateTime.now();
        _ticked = 0;
      });
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(Object e) {
    showToast(context, Online.describe(e));
    Navigator.of(context).pop();
  }

  Future<void> _quit() async {
    if (_end != null) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Arrêter la partie ?'),
        content: const Text('Les réponses déjà données ne rapportent rien.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuer')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Arrêter')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.quiz.quit();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final art = Session.instance.illustration(const ['Genèse']);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        backgroundColor: Palette.night,
        body: Stack(
          children: [
            Positioned.fill(child: GameBackground(art: art)),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14 * k, 6 * k, 14 * k, 10 * k),
                child: _end == null ? _playing(k) : _finished(k, _end!),
              ),
            ),
            if (_end != null && _end!.stars > 0) const Positioned.fill(child: IgnorePointer(child: Celebration())),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Partie

  Widget _header(double k) => Row(
        children: [
          IconButton(
            onPressed: _quit,
            tooltip: 'Arrêter',
            icon: Icon(Icons.close_rounded, color: paleText, size: 28 * k),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(widget.levelName, style: titleStyle(19 * k, goldLight)),
                ),
                Text(_difficultyLabel(widget.quiz.difficulty), style: bodyStyle(12 * k, paleText)),
              ],
            ),
          ),
          if (_end == null && _answer == null)
            ValueListenableBuilder<double>(
              valueListenable: _clock,
              builder: (context, left, _) =>
                  TimerRing(left: left, total: _total, size: 46 * k),
            ),
        ],
      );

  /// Une pastille par question : verte trouvée, rouge ratée, dorée en cours.
  Widget _progress(double k) {
    final total = _question.total;
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Container(
              height: 7 * k,
              margin: EdgeInsets.symmetric(horizontal: 1.5 * k),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4 * k),
                color: i < _results.length
                    ? (_results[i] ? const Color(0xFF4CC46A) : const Color(0xFFE06060))
                    : (i == _results.length ? Palette.gold : const Color(0x33FFFFFF)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _playing(double k) {
    final q = _question;
    final a = _answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(k),
        SizedBox(height: 6 * k),
        _progress(k),
        SizedBox(height: 6 * k),
        Text('Question ${q.number} sur ${q.total}', textAlign: TextAlign.center, style: bodyStyle(12.5 * k, paleText)),
        SizedBox(height: 10 * k),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _scroll(k, q),
                SizedBox(height: 12 * k),
                for (final option in q.options) ...[
                  _option(k, option, a),
                  SizedBox(height: 8 * k),
                ],
                if (a != null) _lesson(k, a),
              ],
            ),
          ),
        ),
        if (a != null) ...[
          SizedBox(height: 8 * k),
          GoldButton(
            a.end != null ? 'Voir le résultat' : 'Question suivante',
            onPressed: _busy ? null : _next,
            height: 52 * k,
            fontSize: 20 * k,
          ),
        ],
      ],
    );
  }

  /// La question, sur un parchement tenu par le Scribe.
  Widget _scroll(double k, QuizQuestion q) => Container(
        padding: EdgeInsets.fromLTRB(16 * k, 14 * k, 16 * k, 16 * k),
        decoration: BoxDecoration(
          color: _parchment,
          borderRadius: BorderRadius.circular(16 * k),
          border: Border.all(color: const Color(0xFFD9AE55), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipOval(child: Image.asset('assets/duel/scribe.png', width: 30 * k, height: 30 * k, fit: BoxFit.cover)),
                SizedBox(width: 8 * k),
                Expanded(child: Text('Le Scribe demande', style: bodyStyle(12 * k, const Color(0xFF7A6646)))),
                PictoIcon(pictoForCategory(q.category), size: 20 * k, color: const Color(0xFF9A7B45), stroke: 1.6),
              ],
            ),
            SizedBox(height: 10 * k),
            Text(q.text, textAlign: TextAlign.center, style: titleStyle(21 * k, _ink).copyWith(height: 1.2)),
          ],
        ),
      );

  Widget _option(double k, String option, QuizAnswer? a) {
    final isAnswer = a != null && option == a.answer;
    final isWrongPick = a != null && option == _picked && !a.correct;
    final Color bg = isAnswer ? _good : (isWrongPick ? _bad : _parchment);
    final Color fg = isAnswer || isWrongPick ? Colors.white : _ink;
    final dimmed = a != null && !isAnswer && !isWrongPick;
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14 * k),
        child: InkWell(
          borderRadius: BorderRadius.circular(14 * k),
          onTap: a == null && !_busy ? () => _reply(option) : null,
          child: Container(
            constraints: BoxConstraints(minHeight: 52 * k),
            padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 10 * k),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14 * k),
              border: Border.all(color: option == _picked && a == null ? Palette.gold : const Color(0x55D9AE55), width: 2),
            ),
            child: Row(
              children: [
                Expanded(child: Text(option, style: bodyStyle(16 * k, fg, weight: 800))),
                if (isAnswer) Icon(Icons.check_circle_rounded, color: Colors.white, size: 22 * k),
                if (isWrongPick) Icon(Icons.cancel_rounded, color: Colors.white, size: 22 * k),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Après la réponse : ce qu'il fallait trouver, et où le lire.
  Widget _lesson(double k, QuizAnswer a) => Container(
        margin: EdgeInsets.only(top: 4 * k),
        padding: EdgeInsets.all(14 * k),
        decoration: BoxDecoration(
          color: const Color(0xE6102552),
          borderRadius: BorderRadius.circular(14 * k),
          border: Border.all(color: a.correct ? const Color(0xFF4CC46A) : const Color(0xFFE06060), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.correct ? 'Bonne réponse !' : (a.timedOut ? 'Temps écoulé.' : 'Ce n’était pas ça.'),
              style: titleStyle(18 * k, a.correct ? const Color(0xFF7BE08F) : const Color(0xFFFF9C9C)),
            ),
            if (!a.correct) ...[
              SizedBox(height: 4 * k),
              Text('Réponse : ${a.answer}', style: bodyStyle(14.5 * k, Palette.cream, weight: 900)),
            ],
            if (a.explanation.isNotEmpty) ...[
              SizedBox(height: 6 * k),
              Text(a.explanation, style: bodyStyle(13.5 * k, paleText, weight: 700)),
            ],
            if (a.reference.isNotEmpty) ...[
              SizedBox(height: 6 * k),
              Text(a.reference, style: bodyStyle(12.5 * k, goldLight, weight: 900)),
            ],
          ],
        ),
      );

  // ---------------------------------------------------------------- Fin

  Widget _finished(double k, QuizEnd e) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(k),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4 * k),
                  child: _star(i < e.stars, (i == 1 ? 74 : 58) * k),
                ),
            ],
          ),
          SizedBox(height: 14 * k),
          Text(
            e.stars == 3 ? 'Parfait !' : (e.stars > 0 ? 'Bien joué !' : 'Encore un effort'),
            textAlign: TextAlign.center,
            style: titleStyle(34 * k, goldLight),
          ),
          SizedBox(height: 6 * k),
          Text('${e.correct} bonne${e.correct > 1 ? 's' : ''} réponse${e.correct > 1 ? 's' : ''} sur ${e.total}',
              textAlign: TextAlign.center, style: bodyStyle(16 * k, Palette.cream, weight: 900)),
          if (e.stars < 3) ...[
            SizedBox(height: 4 * k),
            Text(_nextStarHint(e), textAlign: TextAlign.center, style: bodyStyle(13 * k, paleText)),
          ],
          SizedBox(height: 18 * k),
          Container(
            padding: EdgeInsets.all(14 * k),
            decoration: BoxDecoration(
              color: const Color(0xE6102552),
              borderRadius: BorderRadius.circular(16 * k),
              border: Border.all(color: const Color(0x55D9AE55)),
            ),
            child: Column(
              children: [
                _gain(k, 'Expérience', '+${e.xp} XP'),
                if (e.talents > 0) _gain(k, 'Étoiles nouvelles', '+${e.talents} talents'),
                _gain(k, 'Meilleur résultat', '${e.best} étoile${e.best > 1 ? 's' : ''} sur 3'),
                if (e.levelAfter > e.levelBefore) _gain(k, 'Niveau atteint', 'Niveau ${e.levelAfter}'),
              ],
            ),
          ),
          const Spacer(),
          GoldButton('Retour à l’aventure', onPressed: () => Navigator.of(context).pop(), height: 52 * k, fontSize: 20 * k),
        ],
      );

  String _nextStarHint(QuizEnd e) {
    // Les seuils sont dans les réglages du serveur ; on donne simplement le cap de la prochaine étoile.
    return e.stars == 0 ? 'Trouve plus de réponses pour gagner une étoile.' : 'Trouve-les toutes pour les trois étoiles.';
  }

  Widget _gain(double k, String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * k),
        child: Row(
          children: [
            Expanded(child: Text(label, style: bodyStyle(14.5 * k, paleText))),
            Text(value, style: titleStyle(17 * k, goldLight)),
          ],
        ),
      );

  Widget _star(bool won, double size) => Image.asset(
        'assets/aventure/etoile.png',
        width: size,
        height: size,
        color: won ? null : const Color(0x55FFFFFF),
        colorBlendMode: won ? null : BlendMode.srcIn,
      );

  static String _difficultyLabel(String d) => switch (d) {
        'manne' => 'Manne',
        'solide' => 'Nourriture solide',
        _ => 'Lait',
      };
}
