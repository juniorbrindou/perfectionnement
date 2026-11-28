// L'IA de l'arcade, « le Scribe » (PRD §3.1).

/** Chance de trouver la bonne réponse parmi 4 propositions. */
let CHANCES_IA: { [difficulte: string]: number } = { lait: 0.65, manne: 0.55, solide: 0.45 };
/** Question de départ : chance de répondre juste et délai de réponse (s). */
let CHANCE_DEPART_IA = 0.7;
const DEPART_IA_MIN_S = 3;
const DEPART_IA_MAX_S = 9;

/** Ce que l'IA retient d'une carte : les propositions présentes à chaque passage. */
interface MemoireIA { [carteId: string]: string[]; }

/** Chance de trouver parmi n propositions : plus il en reste peu, plus elle monte. */
function chanceIA(difficulte: string, n: number): number {
  const base = CHANCES_IA.hasOwnProperty(difficulte) ? CHANCES_IA[difficulte] : CHANCES_IA["manne"];
  if (n <= 1) return 1;
  const chance = n >= 4 ? base : base + (1 - base) * (4 - n) / 4;
  return Math.max(chance, 1 / n);
}

/**
 * Réponse de l'IA à une carte. Elle n'oublie rien : la bonne réponse est présente à chaque
 * passage, donc une proposition absente d'un passage précédent est forcément fausse.
 */
function reponseIA(carteId: string, presentees: string[], bonne: string, difficulte: string, memoire: MemoireIA, alea: Alea): string {
  const deja = memoire[carteId];
  let candidates = deja ? presentees.filter(function (p) { return deja.indexOf(p) >= 0; }) : presentees.slice();
  if (candidates.length === 0) candidates = presentees.slice();
  memoire[carteId] = candidates.slice();
  if (candidates.length === 1) return candidates[0];
  let choix: string;
  if (candidates.indexOf(bonne) >= 0 && alea() < chanceIA(difficulte, candidates.length)) {
    choix = bonne;
  } else {
    const fausses = candidates.filter(function (p) { return p !== bonne; });
    choix = fausses[entier(alea, 0, fausses.length - 1)];
  }
  // Une proposition choisie à tort est écartée pour la suite.
  if (choix !== bonne) {
    memoire[carteId] = memoire[carteId].filter(function (p) { return p !== choix; });
  }
  return choix;
}

/** L'IA pose en priorité la carte qui a le plus de propositions (la plus difficile à deviner). */
function carteIA(main: CarteEnJeu[], alea: Alea): number {
  let max = 0;
  main.forEach(function (c) { max = Math.max(max, nombrePropositions(c)); });
  const meilleures: number[] = [];
  main.forEach(function (c, i) { if (nombrePropositions(c) === max) meilleures.push(i); });
  return meilleures[entier(alea, 0, meilleures.length - 1)];
}
