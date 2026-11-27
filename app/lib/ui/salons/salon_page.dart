import 'package:flutter/material.dart';

import '../../state/online.dart';
import '../../state/salons.dart';
import '../game/table.dart';
import '../theme.dart';
import '../toast.dart';
import 'salon_theme.dart';
import 'salons_screen.dart';

/// La fiche d'un salon, dans le thème choisi par son Berger : demander à rejoindre, attendre
/// la réponse, ou (membre) son classement ; le Berger y reçoit les demandes.
class SalonPage extends StatefulWidget {
  final String id;
  final SalonInfo? preview;

  const SalonPage({super.key, required this.id, this.preview});

  @override
  State<SalonPage> createState() => _SalonPageState();
}

class _SalonPageState extends State<SalonPage> {
  late SalonInfo? _salon = widget.preview;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Salons.view(widget.id);
      if (mounted) {
        setState(() {
          _salon = s;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) showToast(context, Online.describe(e));
    }
  }

  Future<void> _act(Future<SalonInfo?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await action();
      if (!mounted) return;
      if (s != null) setState(() => _salon = s);
    } catch (e) {
      if (mounted) showToast(context, Online.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final s = _salon!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quitter le salon ?'),
        content: Text(s.isShepherd
            ? 'Ton score de salon sera perdu. Le premier du classement deviendra Berger.'
            : 'Ton score de salon sera perdu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Rester')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitter')),
        ],
      ),
    );
    if (ok != true) return;
    await _act(() async {
      await Salons.leave();
      return Salons.view(widget.id).catchError((_) => s);
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    final s = _salon;
    final t = SalonTheme.of(s?.theme ?? 'fete');
    return Scaffold(
      backgroundColor: t.background,
      body: SalonBackdrop(
        theme: t,
        headerHeight: 280 * k,
        child: SafeArea(
          child: s == null
              ? Center(child: CircularProgressIndicator(color: t.accent))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SalonTopBar(theme: t, title: ''),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16 * k, 70 * k, 16 * k, 16 * k),
                        children: [
                          if (s.requested && !s.member) _waiting(s, t, k) else _card(s, t, k),
                          if (s.isShepherd && s.requests.isNotEmpty) ...[
                            SizedBox(height: 16 * k),
                            Text('Demandes · ${s.requests.length}', style: titleStyle(19 * k, t.dark ? t.title : t.title)),
                            SizedBox(height: 8 * k),
                            for (final r in s.requests) _requestRow(s, r, t, k),
                          ],
                        ],
                      ),
                    ),
                    Padding(padding: EdgeInsets.fromLTRB(16 * k, 0, 16 * k, 14 * k), child: _actions(s, t, k)),
                  ],
                ),
        ),
      ),
    );
  }

  BoxDecoration _panel(SalonTheme t, double k) => BoxDecoration(
        borderRadius: BorderRadius.circular(22 * k),
        color: t.dark ? null : t.card,
        gradient: t.dark ? const LinearGradient(colors: [Color(0x1FFFD696), Color(0x14FFD696)]) : null,
        border: Border.all(color: t.cardEdge, width: 1),
        boxShadow: [
          BoxShadow(color: t.dark ? const Color(0x1FF2B65A) : const Color(0x2E50592F), blurRadius: t.dark ? 40 : 22, offset: Offset(0, t.dark ? 0 : 8)),
        ],
      );

  Widget _card(SalonInfo s, SalonTheme t, double k) {
    final textColor = t.dark ? t.text : t.text;
    return Container(
      padding: EdgeInsets.fromLTRB(18 * k, 18 * k, 18 * k, 16 * k),
      decoration: _panel(t, k),
      child: Column(
        children: [
          SalonEmblem(name: s.name, color: s.color, size: 66 * k),
          SizedBox(height: 10 * k),
          Text(s.name, textAlign: TextAlign.center, style: titleStyle(26 * k, t.dark ? t.title : t.title)),
          if (s.motto.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4 * k),
              child: Text(
                '« ${s.motto} »',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Garamond',
                  fontStyle: FontStyle.italic,
                  fontSize: 16 * k,
                  height: 1.3,
                  color: t.dark ? const Color(0xFFF1CFA0) : t.soft,
                  fontVariations: const [FontVariation('wght', 500)],
                ),
              ),
            ),
          SizedBox(height: 12 * k),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6 * k,
            runSpacing: 6 * k,
            children: [
              for (final tag in [
                '${s.difficultyLabel}${s.stake > 0 ? ' · ${s.stake} talents' : ''}',
                s.contentLabel,
                '${s.members}/${s.max} membres',
              ])
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * k, vertical: 4 * k),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12 * k),
                    color: t.dark ? const Color(0x2EF2B65A) : t.accent.withValues(alpha: 0.12),
                  ),
                  child: Text(tag, style: bodyStyle(12 * k, t.dark ? const Color(0xFFFFD690) : t.accent, weight: 900)),
                ),
            ],
          ),
          if (s.ranking.isNotEmpty) ...[
            SizedBox(height: 14 * k),
            Divider(color: t.cardEdge, height: 1),
            SizedBox(height: 10 * k),
            for (final r in (s.member ? s.ranking : s.ranking.take(3)))
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4 * k),
                child: Row(
                  children: [
                    PlayerAvatar(name: r.name, color: salonColor(r.name.hashCode % salonColors.length), size: 30 * k),
                    SizedBox(width: 10 * k),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.me ? '${r.name} (toi)' : r.name, style: bodyStyle(13.5 * k, textColor, weight: 900)),
                          if (r.roleLabel.isNotEmpty)
                            Text(r.roleLabel, style: bodyStyle(10.5 * k, t.dark ? t.accent : const Color(0xFFB07D1C), weight: 900)),
                        ],
                      ),
                    ),
                    Text('${r.score} pts', style: bodyStyle(12 * k, t.soft)),
                  ],
                ),
              ),
          ] else if (!_loaded)
            Padding(padding: EdgeInsets.all(12 * k), child: CircularProgressIndicator(color: t.accent, strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _waiting(SalonInfo s, SalonTheme t, double k) => Container(
        padding: EdgeInsets.fromLTRB(18 * k, 22 * k, 18 * k, 20 * k),
        decoration: _panel(t, k),
        child: Column(
          children: [
            Container(
              width: 112 * k,
              height: 112 * k,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(center: Alignment(-0.25, -0.35), colors: [Color(0xFFC25A2A), Color(0xFF7A2A10), Color(0xFF4E170A)], stops: [0, 0.62, 1]),
                border: Border.all(color: const Color(0xFF8E3A16), width: 6 * k),
                boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 10))],
              ),
              child: Text('Demande\nenvoyée', textAlign: TextAlign.center, style: titleStyle(15 * k, const Color(0xFFFFE3B0))),
            ),
            SizedBox(height: 14 * k),
            Text('En attente de ${s.shepherd}', textAlign: TextAlign.center, style: titleStyle(22 * k, t.title)),
            SizedBox(height: 6 * k),
            Text(
              'Le Berger de ${s.name} va lire ta demande. Tu seras prévenu dès qu’il répond.',
              textAlign: TextAlign.center,
              style: bodyStyle(13.5 * k, t.dark ? const Color(0xFFE8CFA4) : t.soft),
            ),
          ],
        ),
      );

  Widget _requestRow(SalonInfo s, SalonRequest r, SalonTheme t, double k) => Container(
        margin: EdgeInsets.only(bottom: 8 * k),
        padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
        decoration: _panel(t, k).copyWith(borderRadius: BorderRadius.circular(14 * k)),
        child: Row(
          children: [
            PlayerAvatar(name: r.name, color: salonColor(r.name.hashCode % salonColors.length), size: 38 * k),
            SizedBox(width: 10 * k),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: titleStyle(16 * k, t.dark ? t.text : t.title)),
                  Text('Niveau ${r.level}', style: bodyStyle(11.5 * k, t.soft)),
                ],
              ),
            ),
            _round(Icons.check_rounded, const Color(0xFF2F8A3A), Colors.white, k, () => _act(() => Salons.answer(s.id, r.player, true))),
            SizedBox(width: 8 * k),
            _round(Icons.close_rounded, const Color(0xFFE8D2AE), const Color(0xFF8E2A22), k, () => _act(() => Salons.answer(s.id, r.player, false))),
          ],
        ),
      );

  Widget _round(IconData icon, Color bg, Color fg, double k, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38 * k,
          height: 38 * k,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(icon, color: fg, size: 22 * k),
        ),
      );

  Widget _actions(SalonInfo s, SalonTheme t, double k) {
    if (!_loaded) return const SizedBox.shrink();
    if (s.member) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GoldButton('Jouer dans le salon', onPressed: () => showToast(context, 'Les parties de salon arrivent dans la prochaine étape.'), height: 52 * k, fontSize: 19 * k),
          TextButton(onPressed: _busy ? null : _leave, child: Text('Quitter le salon', style: bodyStyle(14 * k, t.soft, weight: 900))),
        ],
      );
    }
    if (s.requested) {
      return SalonSecondaryButton(
        text: 'Annuler la demande',
        theme: t,
        onTap: () => _act(() async {
          await Salons.cancelRequest();
          return Salons.view(s.id);
        }),
      );
    }
    final reason = s.otherSalon ? 'Tu es déjà membre d’un autre salon.' : (s.full ? 'Ce salon est complet.' : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GoldButton('Demander à rejoindre', onPressed: reason != null || _busy ? null : () => _act(() => Salons.request(s.id)), height: 52 * k, fontSize: 19 * k),
        SizedBox(height: 8 * k),
        Text(reason ?? 'Tu ne peux être membre que d’un seul salon.', style: bodyStyle(12.5 * k, t.dark ? const Color(0xFFE8CFA4) : t.soft)),
      ],
    );
  }
}

class SalonSecondaryButton extends StatelessWidget {
  final String text;
  final SalonTheme theme;
  final VoidCallback onTap;

  const SalonSecondaryButton({super.key, required this.text, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final k = tableUnit(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50 * k,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25 * k),
          color: theme.dark ? const Color(0xD926130A) : Colors.white.withValues(alpha: 0.6),
          border: Border.all(color: theme.accent.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Text(text, style: titleStyle(17 * k, theme.dark ? const Color(0xFFF3D08A) : theme.accent)),
      ),
    );
  }
}
