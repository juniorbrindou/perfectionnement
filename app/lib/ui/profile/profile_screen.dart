import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/progression.dart';
import '../../core/pseudo.dart';
import '../../state/online.dart';
import '../../state/player.dart';
import '../theme.dart';
import '../../state/sound.dart';

/// Vues de l'écran : le profil, la création de compte, la reprise d'un compte.
enum ProfileView { profile, create, login }

const _pale = Color(0xFFC9D6FF);
const _alert = Color(0xFFFF8FA3);
const _good = Color(0xFF5BE08A);
const _field = Color(0xFF0B1A42);

/// Profil du joueur, porté de scripts/ui/profile.gd (bleu nuit semé de poussière d'or) :
/// pseudo, niveau, compte invité ou protégé, création et reprise de compte.
class ProfileScreen extends StatefulWidget {
  final ProfileView initialView;

  const ProfileScreen({super.key, this.initialView = ProfileView.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ProfileView _view = widget.initialView;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _renaming = false;
  bool _busy = false;
  String? _error;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  bool _visible = false; // Mots de passe affichés en clair.

  final _online = Online.instance;

  @override
  void initState() {
    super.initState();
    // Les repères sous les champs suivent la saisie ; une erreur disparaît dès qu'on corrige.
    _email.addListener(() => setState(() => _emailError = _error = null));
    _password.addListener(() => setState(() => _passwordError = _error = null));
    _confirm.addListener(() => setState(() => _confirmError = _error = null));
    _name.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _show(ProfileView v) => setState(() {
        _view = v;
        _renaming = false;
        _visible = false;
        _password.clear();
        _confirm.clear();
        _error = _emailError = _passwordError = _confirmError = null;
      });

  void _back() {
    if (_view != ProfileView.profile) {
      _show(ProfileView.profile);
    } else if (_renaming) {
      setState(() => _renaming = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Lance une action du compte ; affiche son message d'erreur, ou fait [done].
  Future<void> _run(Future<String?> Function() action, [VoidCallback? done]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (problem != null) {
      setState(() => _error = problem);
    } else {
      done?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = unit(context);
    return PopScope(
      canPop: _view == ProfileView.profile && !_renaming,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1638),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B2C6B), Color(0xFF0B1638)],
            ),
          ),
          child: CustomPaint(
            painter: _GoldDust(),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20 * u, 12 * u, 20 * u, 20 * u),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 32 * u),
                    child: IntrinsicHeight(
                      child: ListenableBuilder(
                        listenable: Player.instance,
                        builder: (context, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: switch (_view) {
                            ProfileView.profile => _profile(u),
                            ProfileView.create => _create(u),
                            ProfileView.login => _login(u),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Vues

  List<Widget> _profile(double u) {
    final player = Player.instance;
    final name = player.username.isEmpty ? 'Invité' : player.username;
    final online = player.connection == Connection.online;
    return [
      _header(u, 'Mon profil'),
      SizedBox(height: 16 * u),
      Center(child: _Avatar(name: name, size: 110 * u, connection: player.connection)),
      SizedBox(height: 8 * u),
      Text(name, textAlign: TextAlign.center, style: titleStyle(30 * u, Palette.cream)),
      SizedBox(height: 14 * u),
      if (player.isKnown) _progress(u),
      SizedBox(height: 10 * u),
      _sounds(u),
      SizedBox(height: 6 * u),
      if (_renaming)
        _rename(u)
      else if (online)
        _link(u, 'Changer de pseudo', () {
          _name.text = player.username;
          setState(() {
            _renaming = true;
            _error = null;
          });
        })
      else ...[
        Center(child: _outline(u, 'Se reconnecter', () => _online.connectGuest())),
        if (_online.lastError.isNotEmpty) _message(u, _online.lastError),
      ],
      const Spacer(),
      SizedBox(height: 14 * u),
      if (_online.hasAccount) _badge(u) else ..._guest(u, online),
    ];
  }

  List<Widget> _guest(double u, bool online) => [
        Container(
          padding: EdgeInsets.all(16 * u),
          decoration: _panel(u, const Color(0xD90D1A40), 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Garde ta progression', style: titleStyle(20 * u, Palette.gold)),
              SizedBox(height: 6 * u),
              Text(
                'Ton compte invité est lié à ce téléphone. Crée un compte pour retrouver ton pseudo, '
                'tes talents et ton niveau sur un autre téléphone.',
                style: bodyStyle(14 * u, _pale),
              ),
              SizedBox(height: 12 * u),
              _google(u, online),
              SizedBox(height: 10 * u),
              _outline(u, 'Créer mon compte avec un e-mail', online ? () => _show(ProfileView.create) : null),
              if (_error != null && !_renaming) _message(u, _error!),
            ],
          ),
        ),
        _link(u, 'J’ai déjà un compte sur un autre téléphone', () => _show(ProfileView.login), color: _pale, size: 14),
      ];

  // ---------------------------------------------------------------- Formulaires

  bool get _keyboardOpen => MediaQuery.viewInsetsOf(context).bottom > 0;

  bool _validEmail(String text) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text.trim());

  void _submitCreate() {
    setState(() {
      _emailError = _validEmail(_email.text) ? null : 'Cette adresse e-mail n’est pas valide.';
      _passwordError = _password.text.length >= 8 ? null : 'Le mot de passe doit faire au moins 8 caractères.';
      _confirmError = _password.text == _confirm.text ? null : 'Les deux mots de passe ne sont pas identiques.';
    });
    if (_emailError != null || _passwordError != null || _confirmError != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _run(() => _online.linkEmail(_email.text, _password.text), () {
      TextInput.finishAutofillContext(); // Propose au téléphone d'enregistrer le mot de passe.
      _show(ProfileView.profile);
    });
  }

  void _submitLogin() {
    setState(() {
      _emailError = _validEmail(_email.text) ? null : 'Cette adresse e-mail n’est pas valide.';
      _passwordError = _password.text.isEmpty ? 'Saisis ton mot de passe.' : null;
    });
    if (_emailError != null || _passwordError != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _run(() => _online.loginEmail(_email.text, _password.text), () {
      TextInput.finishAutofillContext();
      _show(ProfileView.profile);
    });
  }

  List<Widget> _create(double u) {
    final name = Player.instance.username;
    final long = _password.text.length >= 8;
    final same = _confirm.text.isNotEmpty && _confirm.text == _password.text;
    return [
      _header(u, 'Créer mon compte'),
      // Clavier ouvert, la place revient aux champs et au bouton.
      _keyboardOpen
          ? const SizedBox.shrink()
          : Container(
              margin: EdgeInsets.only(top: 10 * u),
              padding: EdgeInsets.all(12 * u),
              decoration: _panel(u, const Color(0x12FFFFFF), 18),
              child: Row(
                children: [
                  _Avatar(name: name, size: 46 * u),
                  SizedBox(width: 12 * u),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: titleStyle(18 * u, Palette.gold)),
                        Text('Ton pseudo et ta progression sont conservés.', style: bodyStyle(13 * u, _pale)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      AutofillGroup(
        key: const ValueKey('champs'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _input(u, 'Adresse e-mail', _email, hint: 'toi@exemple.fr', email: true, error: _emailError),
            _input(u, 'Mot de passe', _password,
                secret: true,
                newPassword: true,
                error: _passwordError,
                help: '8 caractères minimum',
                good: long),
            _input(u, 'Confirme le mot de passe', _confirm,
                secret: true,
                newPassword: true,
                last: _submitCreate,
                error: _confirmError,
                help: _confirm.text.isEmpty ? null : (same ? 'Les mots de passe sont identiques' : 'Pas encore identiques'),
                good: same),
          ],
        ),
      ),
      if (_error != null) _message(u, _error!),
      SizedBox(height: 14 * u),
      _primary(u, 'Créer mon compte', _submitCreate),
      if (!_keyboardOpen) ...[
        SizedBox(height: 12 * u),
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0x33FFFFFF))),
            Padding(padding: EdgeInsets.symmetric(horizontal: 10 * u), child: Text('ou', style: bodyStyle(13 * u, _pale))),
            const Expanded(child: Divider(color: Color(0x33FFFFFF))),
          ],
        ),
        SizedBox(height: 12 * u),
        _google(u, Player.instance.connection == Connection.online, () => _show(ProfileView.profile)),
      ],
    ];
  }

  List<Widget> _login(double u) => [
        _header(u, 'Retrouver mon compte'),
        _keyboardOpen
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(top: 6 * u),
                child: Text(
                  'Connecte-toi avec l’e-mail de ton compte pour retrouver ton pseudo et ta progression sur ce téléphone.',
                  style: bodyStyle(15 * u, _pale),
                ),
              ),
        AutofillGroup(
          key: const ValueKey('champs'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _input(u, 'Adresse e-mail', _email, hint: 'toi@exemple.fr', email: true, error: _emailError),
              _input(u, 'Mot de passe', _password, secret: true, last: _submitLogin, error: _passwordError),
            ],
          ),
        ),
        if (_error != null) _message(u, _error!),
        SizedBox(height: 14 * u),
        _primary(u, 'Me connecter', _submitLogin),
        if (!_keyboardOpen && !_online.hasAccount && Player.instance.username.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 14 * u),
            padding: EdgeInsets.all(12 * u),
            decoration: BoxDecoration(
              color: const Color(0x2EE0315B),
              borderRadius: BorderRadius.circular(16 * u),
              border: Border.all(color: const Color(0x99FF8FA3), width: 2),
            ),
            child: Text(
              'Le compte invité de ce téléphone (${Player.instance.username}) sera remplacé par ton compte.',
              style: bodyStyle(14 * u, Palette.cream),
            ),
          ),
      ];

  // ---------------------------------------------------------------- Éléments

  Widget _header(double u, String text) => Row(
        children: [
          IconButton(
            onPressed: _back,
            tooltip: 'Retour',
            icon: Icon(Icons.chevron_left, color: _pale, size: 32 * u),
          ),
          Expanded(child: Text(text, style: titleStyle(26 * u, Palette.cream))),
        ],
      );

  /// Effets sonores et musique, à couper séparément (PRD §9).
  Widget _sounds(double u) => ListenableBuilder(
        listenable: Sound.instance,
        builder: (context, _) => Row(
          children: [
            for (final (label, on, set) in [
              ('Effets sonores', Sound.instance.effectsOn, Sound.instance.setEffects),
              ('Musique', Sound.instance.musicOn, Sound.instance.setMusic),
            ]) ...[
              if (label == 'Musique') SizedBox(width: 10 * u),
              Expanded(
                child: FilledButton(
                  onPressed: () => set(!on),
                  style: FilledButton.styleFrom(
                    backgroundColor: on ? Palette.gold : _field,
                    side: BorderSide(color: on ? const Color(0xFFFFE9A8) : const Color(0x40FFFFFF)),
                    padding: EdgeInsets.symmetric(horizontal: 4 * u),
                    minimumSize: Size(0, 44 * u),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * u)),
                  ),
                  child: FittedBox(
                    child: Text('$label : ${on ? 'oui' : 'non'}', style: titleStyle(14 * u, on ? Palette.ink : _pale)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _progress(double u) {
    final xp = Player.instance.xp;
    final p = Progression.fromXp(xp);
    return Container(
      padding: EdgeInsets.fromLTRB(16 * u, 12 * u, 16 * u, 12 * u),
      decoration: _panel(u, const Color(0x12FFFFFF), 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Niveau ${p.level}', style: titleStyle(24 * u, Palette.gold))),
              Text(Progression.rank(p.level), style: bodyStyle(15 * u, Palette.cream, weight: 900)),
            ],
          ),
          SizedBox(height: 8 * u),
          ClipRRect(
            borderRadius: BorderRadius.circular(6 * u),
            child: LinearProgressIndicator(
              value: p.toNext == 0 ? 0 : p.inLevel / p.toNext,
              minHeight: 12 * u,
              backgroundColor: const Color(0x1FFFFFFF),
              color: Palette.gold,
            ),
          ),
          SizedBox(height: 6 * u),
          Text('${p.inLevel} / ${p.toNext} XP pour le niveau ${p.level + 1}', style: bodyStyle(13 * u, _pale)),
        ],
      ),
    );
  }

  Widget _rename(double u) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _input(u, 'Nouveau pseudo', _name, maxLength: Pseudo.maxLength),
          if (_error != null) _message(u, _error!),
          SizedBox(height: 10 * u),
          Row(
            children: [
              Expanded(child: _outline(u, 'Annuler', () => setState(() => _renaming = false))),
              SizedBox(width: 10 * u),
              Expanded(
                child: _primary(u, 'Valider',
                    () => _run(() => _online.changeUsername(_name.text), () => setState(() => _renaming = false))),
              ),
            ],
          ),
        ],
      );

  /// Compte protégé : cadenas doré et ce que le compte garantit.
  Widget _badge(double u) => Container(
        padding: EdgeInsets.all(14 * u),
        decoration: _panel(u, const Color(0xB30A1433), 14),
        child: Row(
          children: [
            Icon(Icons.lock, color: Palette.gold, size: 28 * u),
            SizedBox(width: 12 * u),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Compte protégé', style: titleStyle(17 * u, Palette.cream)),
                  Text(
                    'Progression synchronisée · ${_online.googleLinked ? 'Google lié' : 'E-mail lié'}',
                    style: bodyStyle(13 * u, Palette.gold),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// Un champ : libellé, saisie (avec l'œil pour un mot de passe), puis son erreur ou son repère.
  /// Un seul widget avec une clé : le champ garde le focus quand l'écran se réarrange.
  Widget _input(
    double u,
    String label,
    TextEditingController controller, {
    String? hint,
    bool secret = false,
    bool newPassword = false,
    bool email = false,
    int? maxLength,
    String? error,
    String? help,
    bool good = false,
    VoidCallback? last,
  }) =>
      Column(
        key: ValueKey(label),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 10 * u),
          Text(label, style: titleStyle(16 * u, Palette.cream)),
          SizedBox(height: 5 * u),
          TextField(
            controller: controller,
            obscureText: secret && !_visible,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            maxLength: maxLength,
            keyboardType: email ? TextInputType.emailAddress : (secret ? TextInputType.visiblePassword : TextInputType.text),
            textInputAction: last != null || (!email && !secret) ? TextInputAction.done : TextInputAction.next,
            onSubmitted: last == null ? null : (_) => last(),
            autofillHints: email
                ? const [AutofillHints.email]
                : (secret ? [newPassword ? AutofillHints.newPassword : AutofillHints.password] : null),
            style: bodyStyle(16 * u, Palette.cream),
            cursorColor: Palette.gold,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: bodyStyle(16 * u, const Color(0x80C9D6FF)),
              counterText: '',
              filled: true,
              fillColor: _field,
              contentPadding: EdgeInsets.symmetric(horizontal: 14 * u, vertical: 13 * u),
              suffixIcon: secret
                  ? IconButton(
                      onPressed: () => setState(() => _visible = !_visible),
                      tooltip: _visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
                      icon: Icon(_visible ? Icons.visibility_off : Icons.visibility, color: _pale, size: 22 * u),
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14 * u),
                borderSide: BorderSide(color: error == null ? const Color(0x40FFFFFF) : _alert, width: error == null ? 1 : 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14 * u),
                borderSide: BorderSide(color: error == null ? Palette.gold : _alert, width: 2),
              ),
            ),
          ),
          if (error != null || help != null)
            Padding(
              padding: EdgeInsets.only(top: 5 * u),
              child: Row(
                children: [
                  if (error != null || good) ...[
                    Icon(error != null ? Icons.error_outline : Icons.check_circle,
                        color: error != null ? _alert : _good, size: 15 * u),
                    SizedBox(width: 5 * u),
                  ],
                  Expanded(child: Text(error ?? help!, style: bodyStyle(13 * u, error != null ? _alert : (good ? _good : _pale)))),
                ],
              ),
            ),
        ],
      );

  Widget _message(double u, String text) => Padding(
        padding: EdgeInsets.only(top: 8 * u),
        child: Text(text, textAlign: TextAlign.center, style: bodyStyle(14 * u, _alert, weight: 900)),
      );

  Widget _primary(double u, String text, VoidCallback onTap) => FilledButton(
        onPressed: _busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Palette.gold,
          foregroundColor: Palette.ink,
          disabledBackgroundColor: const Color(0x80F6C24A),
          minimumSize: Size.fromHeight(54 * u),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18 * u)),
        ),
        child: Text(_busy ? 'Un instant…' : text, style: titleStyle(20 * u, Palette.ink)),
      );

  Widget _outline(double u, String text, VoidCallback? onTap) => OutlinedButton(
        onPressed: _busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.cream,
          side: BorderSide(color: Color(onTap == null ? 0x33FFFFFF : 0x80FFFFFF), width: 1.5),
          minimumSize: Size(0, 50 * u),
          padding: EdgeInsets.symmetric(horizontal: 14 * u),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * u)),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: titleStyle(16 * u, onTap == null ? const Color(0x80FFFDF5) : Palette.cream)),
      );

  Widget _link(double u, String text, VoidCallback onTap, {Color color = Palette.cream, double size = 17}) => TextButton(
        onPressed: _busy ? null : onTap,
        child: Text(text, textAlign: TextAlign.center, style: titleStyle(size * u, color)),
      );

  /// Bouton « Continuer avec Google » (blanc, selon les règles de marque de Google).
  Widget _google(double u, bool online, [VoidCallback? done]) => FilledButton(
        onPressed: online && !_busy ? () => _run(_online.signInGoogle, done) : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFF1F3F4),
          minimumSize: Size.fromHeight(52 * u),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14 * u),
            side: const BorderSide(color: Color(0xFFDADCE0)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('G', style: titleStyle(22 * u, const Color(0xFF4285F4))),
            SizedBox(width: 10 * u),
            Flexible(child: Text('Continuer avec Google', style: bodyStyle(16 * u, const Color(0xFF1F1F1F)))),
          ],
        ),
      );

  BoxDecoration _panel(double u, Color color, double radius) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius * u),
        border: Border.all(color: const Color(0x2EFFFFFF)),
      );
}

/// Pastille à l'initiale du pseudo, avec le point d'état (vert connecté, doré en connexion).
class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Connection? connection;

  const _Avatar({required this.name, required this.size, this.connection});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1FB5B0),
                border: Border.all(color: Palette.gold, width: size * 0.035),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: titleStyle(size * 0.46, Colors.white)),
            ),
            if (connection != null)
              Positioned(
                right: size * 0.04,
                bottom: size * 0.04,
                child: Container(
                  width: size * 0.18,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (connection!) {
                      Connection.online => const Color(0xFF4CFF7A),
                      Connection.connecting => Palette.gold,
                      Connection.offline => const Color(0xFF8D93A8),
                    },
                    border: Border.all(color: const Color(0xFF0B1638), width: 2),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Poussière d'or, immobile.
class _GoldDust extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(1910);
    for (var i = 0; i < 90; i++) {
      final at = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      canvas.drawCircle(at, 0.7 + rng.nextDouble() * 1.4, Paint()..color = Color.fromRGBO(255, 214, 115, 0.1 + rng.nextDouble() * 0.25));
    }
  }

  @override
  bool shouldRepaint(_GoldDust old) => false;
}
