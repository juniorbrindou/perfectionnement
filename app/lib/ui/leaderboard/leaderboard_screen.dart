import 'package:flutter/material.dart';

import '../../core/progression.dart';
import '../../state/online.dart';
import '../../state/player.dart';
import '../theme.dart';

typedef RankData = ({List<RankRow> top, RankRow? me});

const _pale = Color(0xFFC9D6FF);
const _ring = Color(0xFFF0C05A);

/// « 3 120 XP » : milliers séparés par une espace.
String formatXp(int value) {
  var digits = value.abs().toString();
  var out = '';
  while (digits.length > 3) {
    out = ' ${digits.substring(digits.length - 3)}$out';
    digits = digits.substring(0, digits.length - 3);
  }
  return '${value < 0 ? '-' : ''}$digits$out XP';
}

/// Classement général par XP, porté de scripts/ui/leaderboard.gd : podium des trois premiers,
/// liste jusqu'au 50e, ta place épinglée en bas avec ta progression vers le Rang S.
/// Le serveur tient le classement (leaderboard « xp ») ; on ne fait que le lire.
class LeaderboardScreen extends StatefulWidget {
  /// Lecture du classement (remplaçable pour les tests).
  final Future<RankData?> Function()? load;

  const LeaderboardScreen({super.key, this.load});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  RankData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await (widget.load ?? () => Online.instance.leaderboard(limit: 50))();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _retry() async {
    if (!Online.instance.isOnline) await Online.instance.connectGuest();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final u = unit(context);
    final data = _data;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1638),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2C6B), Color(0xFF0B1638)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14 * u, 6 * u, 14 * u, 12 * u),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Retour',
                      icon: Icon(Icons.chevron_left, color: _pale, size: 32 * u),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Classement', style: titleStyle(30 * u, Palette.gold)),
                          Text('Les ${Progression.rankSPlaces} premiers portent le Rang S',
                              style: bodyStyle(13 * u, Palette.cream)),
                        ],
                      ),
                    ),
                    SizedBox(width: 48 * u),
                  ],
                ),
                SizedBox(height: 10 * u),
                Expanded(child: _content(u, data)),
                if (!_loading && data != null) ...[SizedBox(height: 8 * u), _mine(u, data)],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(double u, RankData? data) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Palette.gold));
    if (data == null) {
      return _message(u, 'Le classement n’a pas pu être chargé.', 'Vérifie ta connexion à Internet, puis réessaie.',
          retry: true);
    }
    if (data.top.isEmpty) {
      return _message(u, 'Personne n’est encore classé.',
          'Gagne de l’XP en jouant contre le Scribe ou en duel : tu seras le premier.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          _podium(u, data.top.take(3).toList()),
          SizedBox(height: 10 * u),
          for (final row in data.top.skip(3)) _row(u, row),
        ],
      ),
    );
  }

  Widget _message(double u, String title, String text, {bool retry = false}) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: titleStyle(20 * u, Palette.cream)),
          SizedBox(height: 8 * u),
          Text(text, textAlign: TextAlign.center, style: bodyStyle(14 * u, _pale)),
          if (retry) ...[
            SizedBox(height: 16 * u),
            FilledButton(
              onPressed: _retry,
              style: FilledButton.styleFrom(backgroundColor: Palette.gold, padding: EdgeInsets.all(14 * u)),
              child: Text('Réessayer', style: titleStyle(18 * u, Palette.ink)),
            ),
          ],
        ],
      );

  /// 2e à gauche, 1er au centre (plus haut), 3e à droite, alignés par le bas.
  Widget _podium(double u, List<RankRow> rows) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final place in const [2, 1, 3])
            Expanded(
              child: place > rows.length
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4 * u),
                      child: _step(u, rows[place - 1], place),
                    ),
            ),
        ],
      );

  Widget _step(double u, RankRow row, int place) {
    final first = place == 1;
    final metal = switch (place) {
      1 => const [Color(0xFFFFF0A8), Color(0xFFE8A92A)],
      2 => const [Color(0xFFFFFFFF), Color(0xFFB9C2CF)],
      _ => const [Color(0xFFFFD2A6), Color(0xFFCD7F3C)],
    };
    final medal = (first ? 62.0 : 50.0) * u;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: EdgeInsets.only(top: medal / 2),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(6 * u, medal / 2 + 4 * u, 6 * u, (first ? 14 : 8) * u),
          decoration: BoxDecoration(
            color: const Color(0xF0173378),
            borderRadius: BorderRadius.circular(14 * u),
            border: Border.all(color: first ? _ring : const Color(0x4DFFFFFF), width: first ? 3 : 2),
          ),
          child: Column(
            children: [
              Text(row.me ? 'Toi' : row.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle((first ? 16 : 13) * u, Palette.cream)),
              SizedBox(height: 4 * u),
              FittedBox(child: Text(formatXp(row.xp), style: titleStyle((first ? 18 : 15) * u, Palette.gold))),
            ],
          ),
        ),
        Container(
          width: medal,
          height: medal,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: metal),
            border: Border.all(color: const Color(0x66000000), width: 2),
          ),
          child: Text('$place', style: titleStyle(medal * 0.46, Palette.ink)),
        ),
      ],
    );
  }

  /// Une couleur tirée du pseudo : un joueur garde toujours la même.
  static Color _colorOf(String name) {
    const colors = [Color(0xFF1FA9A3), Color(0xFF3A6FD8), Color(0xFF7A52E0), Color(0xFFC4501F), Color(0xFF2FAE68), Color(0xFFB8185A)];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }

  Widget _avatar(String name, double size) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _colorOf(name),
          border: Border.all(color: const Color(0xD9FFFFFF), width: 1.5),
        ),
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: titleStyle(size * 0.48, Colors.white)),
      );

  Widget _row(double u, RankRow row) => Container(
        margin: EdgeInsets.only(bottom: 6 * u),
        padding: EdgeInsets.symmetric(horizontal: 12 * u, vertical: 7 * u),
        decoration: BoxDecoration(
          color: const Color(0xE612265C),
          borderRadius: BorderRadius.circular(12 * u),
          border: Border.all(color: row.me ? _ring : const Color(0x24FFFFFF)),
        ),
        child: Row(
          children: [
            SizedBox(width: 28 * u, child: Text('${row.place}', style: titleStyle(18 * u, Palette.cream))),
            _avatar(row.name, 32 * u),
            SizedBox(width: 10 * u),
            Expanded(
              child: Text(row.me ? 'Toi' : row.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle(16 * u, Palette.cream)),
            ),
            Text(formatXp(row.xp), style: titleStyle(16 * u, Palette.gold)),
          ],
        ),
      );

  /// Ta ligne, épinglée : ta place et ce qu'il te manque pour le Rang S.
  Widget _mine(double u, RankData data) {
    final place = data.me?.place ?? 0;
    final xp = data.me?.xp ?? Player.instance.xp;
    final name = Player.instance.username;
    final rank = Progression.rank(Progression.fromXp(xp).level);
    final last = data.top.length >= Progression.rankSPlaces ? data.top[Progression.rankSPlaces - 1] : null;
    final String status;
    var ratio = place > 0 ? 1.0 : 0.0;
    if (place <= 0) {
      status = '$rank : pas encore classé. Gagne de l’XP en jouant.';
    } else if (Progression.hasRankS(place)) {
      status = '$rank : tu portes le Rang S.';
    } else if (last == null) {
      status = rank;
    } else {
      status = '$rank : encore ${formatXp(last.xp - xp + 1)} pour le Rang S.';
      ratio = (xp / (last.xp + 1)).clamp(0.0, 1.0);
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * u, vertical: 9 * u),
      decoration: BoxDecoration(
        color: const Color(0xF2163A86),
        borderRadius: BorderRadius.circular(18 * u),
        border: Border.all(color: _ring, width: 2),
      ),
      child: Row(
        children: [
          SizedBox(width: 34 * u, child: Text(place > 0 ? '$place' : '–', style: titleStyle(22 * u, Palette.gold))),
          _avatar(name, 40 * u),
          SizedBox(width: 10 * u),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Toi', style: titleStyle(17 * u, Palette.cream))),
                    Text(formatXp(xp), style: titleStyle(16 * u, Palette.gold)),
                  ],
                ),
                Text(status, style: bodyStyle(12 * u, _pale)),
                SizedBox(height: 4 * u),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4 * u),
                  child: LinearProgressIndicator(
                      value: ratio, minHeight: 7 * u, backgroundColor: const Color(0x29FFFFFF), color: Palette.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
