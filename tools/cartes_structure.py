#!/usr/bin/env python3
"""Génère les cartes « Structure de la Bible » dans data/cartes.json et data/en_ligne/cartes.json.

Les cartes de catégorie « structure » déjà présentes sont remplacées ; les autres ne bougent pas.
Une carte sur deux va dans chaque réserve (aucune commune : anti-triche). Toutes en « brouillon ».
Nombres de chapitres recomptés sur la Louis Segond 1910 (1 189 au total).
Lancement, depuis la racine du dépôt : python3 tools/cartes_structure.py
"""
import json
import random

AT = ["Genèse", "Exode", "Lévitique", "Nombres", "Deutéronome", "Josué", "Juges", "Ruth",
      "1 Samuel", "2 Samuel", "1 Rois", "2 Rois", "1 Chroniques", "2 Chroniques", "Esdras",
      "Néhémie", "Esther", "Job", "Psaumes", "Proverbes", "Ecclésiaste", "Cantique des cantiques",
      "Ésaïe", "Jérémie", "Lamentations", "Ézéchiel", "Daniel", "Osée", "Joël", "Amos", "Abdias",
      "Jonas", "Michée", "Nahum", "Habacuc", "Sophonie", "Aggée", "Zacharie", "Malachie"]
NT = ["Matthieu", "Marc", "Luc", "Jean", "Actes", "Romains", "1 Corinthiens", "2 Corinthiens",
      "Galates", "Éphésiens", "Philippiens", "Colossiens", "1 Thessaloniciens",
      "2 Thessaloniciens", "1 Timothée", "2 Timothée", "Tite", "Philémon", "Hébreux", "Jacques",
      "1 Pierre", "2 Pierre", "1 Jean", "2 Jean", "3 Jean", "Jude", "Apocalypse"]
LIVRES = AT + NT
CHAPITRES = [50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10, 13, 10, 42, 150, 31, 12, 8,
             66, 52, 5, 48, 12, 14, 3, 9, 1, 4, 7, 3, 3, 3, 2, 14, 4,
             28, 16, 24, 21, 28, 16, 16, 13, 6, 6, 4, 4, 5, 3, 6, 4, 3, 1, 13, 5, 5, 3, 5, 1, 1, 1, 22]
assert len(LIVRES) == len(CHAPITRES) == 66 and sum(CHAPITRES) == 1189

CONNUS = {"Genèse", "Exode", "Psaumes", "Matthieu", "Marc", "Luc", "Jean", "Actes", "Romains", "Apocalypse", "Ruth", "Jonas"}
alea = random.Random(1910)


def testament(livre):
    return "AT" if livre in AT else "NT"


def carte(difficulte, question, reponse, fausses, reference, explication, livre=None, test=""):
    assert len(fausses) == 5 and len({reponse, *fausses}) == 6, question
    return {
        "id": "", "difficulty": difficulte, "testament": testament(livre) if livre else test,
        "books": [livre] if livre else [], "category": "structure", "question": question, "answer": reponse,
        "wrongs": fausses, "reference": reference, "explanation": explication, "story": "structure",
        "status": "brouillon",
    }


def generales():
    """Les faits, chacun avec ses fausses réponses. Aucun livre : l'image trahirait la réponse."""
    f = [
        ("lait", "Quel est le plus petit verset de la Bible ?", "« Jésus pleura »",
         ["« Priez sans cesse »", "« Tu ne tueras point »", "« Soyez toujours joyeux »", "« Tu ne déroberas point »", "« L'Éternel me dit »"],
         "Jean 11:35", "« Jésus pleura » : deux mots dans la Louis Segond."),
        ("manne", "Dans quel livre se trouve le plus petit verset de la Bible ?", "Jean",
         ["Luc", "Matthieu", "Psaumes", "1 Thessaloniciens", "Exode"], "Jean 11:35", "C'est « Jésus pleura », devant le tombeau de Lazare."),
        ("solide", "Quel est le plus long verset du Nouveau Testament ?", "Apocalypse 20:4",
         ["Actes 14:15", "Apocalypse 17:8", "Galates 2:16", "Éphésiens 1:13", "Hébreux 12:1"], "Apocalypse 20:4", "Il décrit les trônes et le règne de mille ans."),
        ("lait", "Quel livre de la Bible a le plus grand nombre de chapitres ?", "Psaumes",
         ["Ésaïe", "Jérémie", "Genèse", "Ézéchiel", "Job"], "Psaumes 1–150", "Le livre des Psaumes en compte 150."),
        ("manne", "Quel est le chapitre le plus long de la Bible ?", "Psaume 119",
         ["Psaume 78", "Nombres 7", "Psaume 89", "Deutéronome 28", "1 Rois 8"], "Psaumes 119", "Il suit les lettres de l'alphabet hébreu."),
        ("solide", "Combien de versets compte le plus long chapitre de la Bible ?", "176",
         ["150", "119", "89", "162", "200"], "Psaumes 119", "Le Psaume 119 compte 176 versets."),
        ("manne", "Quel est le chapitre le plus court de la Bible ?", "Psaume 117",
         ["Psaume 23", "Psaume 1", "Psaume 134", "Psaume 100", "Abdias 1"], "Psaumes 117", "Il ne compte que deux versets."),
        ("manne", "La Bible a deux grands « testaments ». Que signifie ici le mot testament ?", "Alliance",
         ["Héritage écrit", "Témoignage", "Prophétie", "Commandement", "Histoire"], "Jérémie 31:31 ; Hébreux 8:8", "L'ancienne et la nouvelle alliance."),
        ("lait", "Combien de livres compte l'Ancien Testament dans la Bible Louis Segond ?", "39",
         ["27", "36", "37", "42", "50"], "Sommaire de la Bible", "De la Genèse à Malachie."),
        ("lait", "Combien de livres compte le Nouveau Testament ?", "27",
         ["29", "24", "30", "21", "39"], "Sommaire de la Bible", "De Matthieu à l'Apocalypse."),
        ("lait", "Combien de livres compte la Bible Louis Segond en tout ?", "66",
         ["60", "56", "70", "72", "77"], "Sommaire de la Bible", "39 dans l'Ancien Testament et 27 dans le Nouveau."),
        ("manne", "Comment appelle-t-on les cinq premiers livres de la Bible, la Torah ?", "Le Pentateuque",
         ["Le Décalogue", "Le Psautier", "Les Évangiles", "La Septante", "Les Proverbes"], "Genèse à Deutéronome", "Pentateuque veut dire « cinq rouleaux »."),
    ]
    return [carte(d, q, r, w, ref, e) for d, q, r, w, ref, e in f]


def chapitres():
    cartes = []
    for i, livre in enumerate(LIVRES):
        n = CHAPITRES[i]
        pas = 1 if n <= 30 else 3 if n <= 70 else 10
        proches = [x for x in (n + k * pas for k in range(-5, 8)) if x >= 1 and x != n]
        fausses = alea.sample(proches, 5)
        cartes.append(carte(
            "manne" if livre in CONNUS else "solide",
            "Combien de chapitres compte le livre « %s » ?" % livre, str(n), [str(x) for x in fausses],
            "%s 1%s" % (livre, "–%d" % n if n > 1 else ""),
            "Il compte %d chapitre%s." % (n, "s" if n > 1 else ""), livre))
    return cartes


def suivants():
    """50 questions « quel livre vient après … », réparties sur toute la Bible."""
    choisis = sorted(alea.sample(range(65), 50))
    cartes = []
    for i in choisis:
        livre, apres = LIVRES[i], LIVRES[i + 1]
        voisins = [LIVRES[j] for j in sorted((j for j in range(66) if j not in (i, i + 1)), key=lambda j: abs(j - i - 1))[:9]]
        difficulte = "lait" if i < 5 or 39 <= i < 44 else "solide" if 25 <= i < 38 or 47 <= i < 64 else "manne"
        cartes.append(carte(
            difficulte, "Quel livre vient juste après « %s » ?" % livre, apres, alea.sample(voisins, 5),
            "Sommaire de la Bible", "Après %s vient %s." % (livre, apres), livre))
    return cartes


def groupes():
    tous = ["Le Pentateuque", "Les livres historiques", "Les livres poétiques", "Les grands prophètes",
            "Les petits prophètes", "Les Évangiles", "Les Actes des Apôtres", "Les épîtres", "L'Apocalypse"]
    questions = [
        ("lait", "le Pentateuque", 1), ("manne", "les livres historiques", 2), ("manne", "les livres poétiques", 3),
        ("solide", "les grands prophètes", 4), ("manne", "les petits prophètes", 5), ("lait", "les Évangiles", 6),
        ("manne", "les épîtres", 8),
    ]
    cartes = []
    for difficulte, avant, i in questions:
        fausses = [g for j, g in enumerate(tous) if j not in (i, i - 1)]
        cartes.append(carte(
            difficulte, "Quel groupe de livres vient juste après %s ?" % avant, tous[i], alea.sample(fausses, 5),
            "Sommaire de la Bible", "Dans la Louis Segond : après %s viennent %s." % (avant, tous[i][0].lower() + tous[i][1:])))
    return cartes


def main():
    toutes = generales() + chapitres() + suivants() + groupes()
    assert len({c["question"] for c in toutes}) == len(toutes)
    for n, c in enumerate(toutes, 1):
        c["id"] = "ST-%03d" % n
    for chemin, part in (("data/en_ligne/cartes.json", toutes[0::2]), ("data/cartes.json", toutes[1::2])):
        with open(chemin, encoding="utf-8") as f:
            gardees = [c for c in json.load(f) if c["category"] != "structure"]
        with open(chemin, "w", encoding="utf-8") as f:
            json.dump(gardees + part, f, ensure_ascii=False, indent=2)
            f.write("\n")
        comptes = {d: sum(c["difficulty"] == d for c in part) for d in ("lait", "manne", "solide")}
        print(chemin, ":", len(gardees), "+", len(part), "structure", comptes)


if __name__ == "__main__":
    main()
