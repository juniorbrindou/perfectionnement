// Règles pures (sans Nakama), testées par test/run.js.
// Valeurs du PRD §4 ; à rééquilibrer après les tests (PRD §13).

const CAPITAL_DEPART = 100;
const PAIN_QUOTIDIEN = 10;
const MISES_DUEL: { [difficulte: string]: number } = { lait: 5, manne: 20, solide: 50 };
const MISES_ARCADE: { [difficulte: string]: number } = { lait: 2, manne: 5, solide: 10 };
const JOUR_MS = 24 * 60 * 60 * 1000;

/** Jour civil UTC d'un instant, au format AAAA-MM-JJ (la Côte d'Ivoire est en UTC). */
function jourUtc(ms: number): string {
  const d = new Date(ms);
  const deux = function (n: number): string { return n < 10 ? "0" + n : String(n); };
  return d.getUTCFullYear() + "-" + deux(d.getUTCMonth() + 1) + "-" + deux(d.getUTCDate());
}

/** Le pain quotidien est disponible si le dernier n'a pas été pris le même jour UTC. */
function painDisponible(dernierJour: string | null, maintenantMs: number): boolean {
  return dernierJour !== jourUtc(maintenantMs);
}

/** Instant (ms) du prochain pain quotidien : minuit UTC suivant. */
function prochainPain(maintenantMs: number): number {
  return Math.floor(maintenantMs / JOUR_MS) * JOUR_MS + JOUR_MS;
}

// ---------------------------------------------------------------- XP, niveaux et rangs (PRD §7)
// Même table que scripts/core/progression.gd : les tests des deux côtés vérifient les mêmes seuils.

const XP_VICTOIRE = 30;
const XP_DEFAITE = 10;
const RANGS: { niveau: number; nom: string }[] = [
  { niveau: 1, nom: "Débutant" },
  { niveau: 6, nom: "Explorateur" },
  { niveau: 11, nom: "Connaisseur" },
  { niveau: 21, nom: "Expert" },
  { niveau: 36, nom: "Maître biblique" },
];

/** XP à gagner pour passer du niveau n au niveau n + 1 : 100, puis 50 de plus à chaque niveau. */
function xpPourMonter(n: number): number {
  return 100 + 50 * (n - 1);
}

/** Niveau atteint avec une XP totale, XP gagnée dans ce niveau et XP qu'il faut pour le suivant. */
function niveauDepuisXp(xp: number): { niveau: number; dansNiveau: number; pourSuivant: number } {
  let niveau = 1;
  let reste = Math.max(0, Math.floor(xp));
  while (reste >= xpPourMonter(niveau)) {
    reste -= xpPourMonter(niveau);
    niveau++;
  }
  return { niveau: niveau, dansNiveau: reste, pourSuivant: xpPourMonter(niveau) };
}

/** Rang d'un niveau (le Rang S, réservé aux 10 premiers du classement, viendra avec la 0.5). */
function rang(niveau: number): string {
  let nom = RANGS[0].nom;
  RANGS.forEach(function (r) { if (niveau >= r.niveau) nom = r.nom; });
  return nom;
}

/** XP d'une partie terminée : une partie abandonnée ne rapporte rien. */
function xpDePartie(gagne: boolean, abandon: boolean): number {
  if (gagne) return XP_VICTOIRE;
  return abandon ? 0 : XP_DEFAITE;
}

/** Mise d'une partie, ou -1 si la difficulté est inconnue. */
function mise(mode: string, difficulte: string): number {
  const table = mode === "arcade" ? MISES_ARCADE : MISES_DUEL;
  return table.hasOwnProperty(difficulte) ? table[difficulte] : -1;
}
