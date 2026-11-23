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

/** Mise d'une partie, ou -1 si la difficulté est inconnue. */
function mise(mode: string, difficulte: string): number {
  const table = mode === "arcade" ? MISES_ARCADE : MISES_DUEL;
  return table.hasOwnProperty(difficulte) ? table[difficulte] : -1;
}
