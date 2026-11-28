import 'package:flutter/material.dart';

import '../../core/bible_books.dart';
import '../../state/online.dart';
import '../../state/player.dart';
import '../../state/reglages.dart';
import '../../state/salons.dart';
import '../game/pictos.dart';
import '../game/table.dart';
import '../theme.dart';
import '../toast.dart';
import 'salon_theme.dart';
import 'salons_screen.dart';

/// Créer un salon (docs/maquettes/salon_creation.html) : d'abord son visage (nom, devise, écu,
/// thème, qui change aussitôt le décor), puis ses règles (difficulté, questions).
class SalonCreateScreen extends StatefulWidget {
  const SalonCreateScreen({super.key});

  @override
  State<SalonCreateScreen> createState() => _SalonCreateScreenState();
}

class _SalonCreateScreenState extends State<SalonCreateScreen> {
  /// Coût de création, réglé depuis le back-office.
  int get _cost => Reglages.instance.salonCout;
  static const _categories = {
    'personnages': 'Personnages',
    'miracles': 'Miracles',
    'paraboles': 'Paraboles',
    'lieux_evenements': 'Lieux et événements',
    'structure': 'Structure de la Bible',
  };

  final _name = TextEditingController();
  final _motto = TextEditingController();
  int _step = 1;
  int _color = 0;
  SalonTheme _theme = SalonTheme.fete;
  String _difficulty = 'lait';
  String _content = 'bible';
  final Set<String> _values = {};
  Map<String, dynamic>? _options;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    Salons.options()
        .then((o) {
          if (mounted) setState(() => _options = o);
        })
        .catchError((Object e) {
          if (mounted) showToast(context, Online.describe(e));
        });
  }

  @override
  void dispose() {
    _name.dispose();
    _motto.dispose();
    super.dispose();
  }

  int get _minimum => (_options?['minimum'] as num?)?.toInt() ?? 40;
  Map<String, dynamic> get _counts =>
      ((_options?['difficultes'] as Map?)?[_difficulty] as Map?)?.cast<String, dynamic>() ?? const {};
  int _count(String group, String key) => ((_counts[group] as Map?)?[key] as num?)?.toInt() ?? 0;
  int get _total => (_counts['total'] as num?)?.toInt() ?? 0;

  /// Questions disponibles pour un choix (approché pour plusieurs livres : une carte peut en citer deux).
  int _available(String type, Iterable<String> values) => switch (type) {
    'testament' => values.fold(0, (n, v) => n + _count('testaments', v)),
    'livres' => values.fold(0, (n, v) => n + _count('livres', v)),
    'categorie' => values.fold(0, (n, v) => n + _count('categories', v)),
    _ => _total,
  };

  bool get _nameOk => _name.text.trim().length >= 3;
  bool get _rulesOk => (_content == 'bible' || _values.isNotEmpty) && _available(_content, _values) >= _minimum;

  Future<void> _create() async {
    if (_busy || !_rulesOk) return;
    if (Player.instance.talents < _cost) {
      showToast(context, 'Il faut $_cost talents pour créer un salon.');
      return;
    }
    setState(() => _busy = true);
    try {
      final s = await Salons.create(
        name: _name.text.trim(),
        motto: _motto.text.trim(),
        color: _color,
        theme: _theme.id,
        difficulty: _difficulty,
        contentType: _content,
        contentValues: _content == 'bible' ? const [] : _values.toList(),
      );
      await Online.instance.refreshAccount();
      if (mounted) Navigator.of(context).pop(s);
    } catch (e) {
      if (mounted) showToast(context, Online.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final t = _theme;
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 1);
      },
      child: Scaffold(
        backgroundColor: t.background,
        body: SalonBackdrop(
          theme: t,
          headerHeight: (_step == 1 ? 230 : 170) * k,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 40 * k),
                SalonTopBar(
                  theme: t,
                  title: _step == 1 ? 'Créer un salon' : 'Les règles',
                  subtitle: _step == 1 ? 'Étape 1 sur 2 · Ton salon' : 'Étape 2 sur 2 · Les questions',
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16 * k, 14 * k, 16 * k, 12 * k),
                    children: _step == 1 ? _face(k) : _rules(k),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16 * k, 0, 16 * k, 12 * k),
                  child: _step == 1
                      ? SalonButton(
                          'Continuer',
                          theme: t,
                          onPressed: _nameOk ? () => setState(() => _step = 2) : null,
                          height: 52 * k,
                          fontSize: 19 * k,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SalonButton(
                              'Créer le salon · $_cost talents',
                              theme: t,
                              onPressed: _rulesOk && !_busy ? _create : null,
                              height: 52 * k,
                              fontSize: 19 * k,
                            ),
                            SizedBox(height: 6 * k),
                            Text(
                              'Il te restera ${Player.instance.talents - _cost} talents.',
                              style: bodyStyle(12.5 * k, t.dark ? t.soft : t.soft),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Étape 1 : le visage du salon

  List<Widget> _face(double k) => [
    _Panel(
      children: [
        _Label('Nom'),
        _Field(controller: _name, max: 24, hint: 'Les Psalmistes'),
        SizedBox(height: 12 * k),
        _Label('Devise'),
        _Field(controller: _motto, max: 60, hint: 'Une phrase pour ton salon (facultatif)', serif: true),
        SizedBox(height: 12 * k),
        _Label('Écu'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < salonColors.length; i++)
              Padding(
                padding: EdgeInsets.zero,
                child: GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    padding: EdgeInsets.all(2.5 * k),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13 * k),
                      border: Border.all(color: i == _color ? _theme.panelAccent : Colors.transparent, width: 2.5),
                    ),
                    child: SalonEmblem(
                      name: _name.text.trim().isEmpty ? 'S' : _name.text.trim(),
                      color: i,
                      size: 34 * k,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 12 * k),
        _Label('Thème'),
        Row(
          children: [
            for (final th in SalonTheme.all) ...[
              if (th != SalonTheme.all.first) SizedBox(width: 8 * k),
              Expanded(child: _themeChoice(th, k)),
            ],
          ],
        ),
      ],
    ),
  ];

  Widget _themeChoice(SalonTheme th, double k) {
    final on = th == _theme;
    return GestureDetector(
      onTap: () => setState(() => _theme = th),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12 * k),
          border: Border.all(color: on ? _theme.panelAccent : const Color(0xFFDCCDB0), width: on ? 2.5 : 1.5),
          boxShadow: on ? const [BoxShadow(color: Color(0x40000000), blurRadius: 10)] : null,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 62 * k,
              width: double.infinity,
              child: SalonThemeThumb(theme: th),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5 * k),
              child: Text(
                th.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: titleStyle(12.5 * k, const Color(0xFF3A2A1A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Étape 2 : les règles

  List<Widget> _rules(double k) {
    final books = ((_counts['livres'] as Map?)?.keys.map((e) => '$e').toList() ?? <String>[])
      ..sort((a, b) => BibleBooks.canonicalIndex(a).compareTo(BibleBooks.canonicalIndex(b)));
    return [
      _Panel(
        children: [
          _Label('Difficulté'),
          Row(
            children: [
              for (final (d, label) in const [('lait', 'Lait'), ('manne', 'Manne'), ('solide', 'Solide')]) ...[
                if (d != 'lait') SizedBox(width: 8 * k),
                Expanded(child: _difficultyChoice(d, label, Reglages.instance.miseDuel(d), k)),
              ],
            ],
          ),
          SizedBox(height: 12 * k),
          _Label('Questions'),
          if (_options == null)
            Padding(
              padding: EdgeInsets.all(10 * k),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            _contentOption('bible', 'Toute la Bible', _total, k),
            _contentOption(
              'testament',
              'Un Testament',
              _available('testament', const ['AT', 'NT']),
              k,
              sub: [
                for (final v in const ['AT', 'NT'])
                  (v, v == 'AT' ? 'Ancien Testament' : 'Nouveau Testament', _count('testaments', v)),
              ],
            ),
            _contentOption(
              'livres',
              'Des livres',
              _available('livres', books),
              k,
              sub: [for (final b in books) (b, b, _count('livres', b))],
            ),
            _contentOption(
              'categorie',
              'Une catégorie',
              _available('categorie', _categories.keys),
              k,
              sub: [for (final e in _categories.entries) (e.key, e.value, _count('categories', e.key))],
            ),
          ],
        ],
      ),
      SizedBox(height: 10 * k),
      _Panel(
        children: [
          Row(
            children: [
              SalonEmblem(name: _name.text.trim(), color: _color, size: 54 * k),
              SizedBox(width: 12 * k),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name.text.trim(), style: titleStyle(20 * k, const Color(0xFF2B2A33))),
                    Text(
                      _summary(),
                      style: const TextStyle(
                        fontFamily: 'Garamond',
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF5A4A3A),
                      ).copyWith(fontSize: 14 * k),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_rulesOk && _options != null)
            Padding(
              padding: EdgeInsets.only(top: 8 * k),
              child: Text(
                _content != 'bible' && _values.isEmpty
                    ? 'Choisis au moins un élément.'
                    : 'Pas encore assez de questions : il en faut $_minimum.',
                style: bodyStyle(12.5 * k, const Color(0xFF9A5A3A), weight: 900),
              ),
            ),
        ],
      ),
    ];
  }

  String _summary() {
    final d = {'lait': 'Lait', 'manne': 'Manne', 'solide': 'Solide'}[_difficulty];
    final c = switch (_content) {
      'testament' => _values.map((v) => v == 'AT' ? 'Ancien Testament' : 'Nouveau Testament').join(', '),
      'livres' => _values.join(', '),
      'categorie' => _values.map((v) => _categories[v] ?? v).join(', '),
      _ => 'Toute la Bible',
    };
    return '$d · ${c.isEmpty ? '…' : c}';
  }

  Widget _difficultyChoice(String d, String label, int stake, double k) {
    final on = d == _difficulty;
    return GestureDetector(
      onTap: () => setState(() {
        _difficulty = d;
        _values.clear();
      }),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8 * k),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12 * k),
          border: Border.all(color: on ? _theme.panelAccent : const Color(0xFFDCCDB0), width: on ? 2.5 : 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 34 * k,
              height: 34 * k,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(center: Alignment(-0.2, -0.3), colors: [Color(0xFF1D3266), Color(0xFF0C1838)]),
              ),
              child: PictoIcon(pictoForDifficulty(d), size: 18 * k),
            ),
            SizedBox(height: 4 * k),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Garamond',
                color: Color(0xFF1D2A4A),
                fontVariations: [FontVariation('wght', 600)],
              ).copyWith(fontSize: 16 * k),
            ),
            Text('mise $stake', style: bodyStyle(11 * k, const Color(0xFF8A5A12), weight: 900)),
          ],
        ),
      ),
    );
  }

  Widget _contentOption(String type, String label, int count, double k, {List<(String, String, int)> sub = const []}) {
    final on = _content == type;
    final enough = count >= _minimum;
    return Padding(
      padding: EdgeInsets.only(bottom: 6 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: enough
                ? () => setState(() {
                    _content = type;
                    _values.clear();
                  })
                : null,
            child: Opacity(
              opacity: enough ? 1 : 0.5,
              child: Container(
                height: 40 * k,
                padding: EdgeInsets.symmetric(horizontal: 12 * k),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12 * k),
                  border: Border.all(color: on ? _theme.panelAccent : const Color(0xFFDCCDB0), width: on ? 2 : 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18 * k,
                      height: 18 * k,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: on ? _theme.panelAccent : const Color(0xFFC9B89A),
                          width: on ? 5 * k : 2,
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * k),
                    Text(label, style: bodyStyle(14 * k, const Color(0xFF2B2A33))),
                    const Spacer(),
                    Text(
                      enough ? '$count questions' : 'Pas encore assez',
                      style: bodyStyle(11.5 * k, enough ? _theme.panelAccent : const Color(0xFF9A5A3A), weight: 900),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (on && sub.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(30 * k, 6 * k, 0, 2 * k),
              child: Wrap(
                spacing: 5 * k,
                runSpacing: 5 * k,
                children: [
                  for (final (value, text, n) in sub)
                    GestureDetector(
                      onTap: n == 0
                          ? null
                          : () => setState(() => _values.contains(value) ? _values.remove(value) : _values.add(value)),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 4 * k),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10 * k),
                          color: _values.contains(value) ? _theme.panelAccent : const Color(0xFFF1E8D6),
                        ),
                        child: Text(
                          '$text · $n',
                          style: bodyStyle(
                            12 * k,
                            _values.contains(value) ? Colors.white : const Color(0xFF6A5A40),
                            weight: 900,
                          ),
                        ),
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

class _Panel extends StatelessWidget {
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Container(
      padding: EdgeInsets.fromLTRB(14 * k, 14 * k, 14 * k, 12 * k),
      decoration: BoxDecoration(
        color: const Color(0xF0FFFCF4),
        borderRadius: BorderRadius.circular(20 * k),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 26, offset: Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 5 * k),
      child: Text(text, style: bodyStyle(13 * k, const Color(0xFF5A4A3A), weight: 900)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final int max;
  final String hint;
  final bool serif;

  const _Field({required this.controller, required this.max, required this.hint, this.serif = false});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final style = serif
        ? const TextStyle(
            fontFamily: 'Garamond',
            fontStyle: FontStyle.italic,
            color: Color(0xFF4A3A2A),
            fontVariations: [FontVariation('wght', 500)],
          ).copyWith(fontSize: 16 * k)
        : bodyStyle(15 * k, const Color(0xFF2B2A33));
    return TextField(
      controller: controller,
      maxLength: max,
      style: style,
      cursorColor: const Color(0xFFE0961A),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hint,
        hintStyle: style.copyWith(color: const Color(0xFFB0A08A)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 11 * k),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12 * k),
          borderSide: const BorderSide(color: Color(0xFFDCCDB0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12 * k),
          borderSide: const BorderSide(color: Color(0xFFE0961A), width: 2),
        ),
      ),
    );
  }
}
