// Règles du duel (PRD §2), version serveur de scripts/core/duel.gd et card_in_play.gd.
// L'état est un objet JSON simple, rangé dans le stockage Nakama entre deux appels.
// Les scénarios communs tests/scenarios/*.json vérifient que les deux versions concordent.

interface CarteSource {
  id: string; difficulty: string; books: string[]; answer: string; wrongs: string[];
  // Textes envoyés au client (la réserve en ligne n'est pas dans l'APK) ; absents des scénarios de test.
  testament?: string; category?: string; question?: string; reference?: string; explanation?: string; story?: string;
}
interface QuestionDepartSource { id: string; question?: string; answer: string; wrongs: string[]; }
interface NiveauSource { id: number; nom: string; }
interface ChapitreSource { nom: string; resume: string; livres: string[]; niveaux: NiveauSource[]; }
interface AventureSource { chapitres: ChapitreSource[]; }

/** Tirage dans [0, 1[, injecté pour rendre les tests reproductibles. */
type Alea = () => number;

/** Une carte dans une partie : 3 fausses réponses affichées au départ, 2 en réserve. */
interface CarteEnJeu { id: string; reponse: string; montrees: string[]; reserve: string[]; }

interface EtatDuel {
  phase: string;               // "depart", "choisir", "repondre" ou "finie"
  mains: CarteEnJeu[][];
  detruites: string[][];       // identifiants des cartes détruites, par propriétaire
  poseur: number;
  gagnant: number;
  jouee: CarteEnJeu | null;
  indexJouee: number;
  presentees: string[];
}

interface ResultatCoup { juste: boolean; carte: string; proprietaire: number; choix: string; }

const TAILLE_MAIN = 5;
const FAUSSES_AFFICHEES = 3;

function entier(alea: Alea, min: number, max: number): number {
  return min + Math.floor(alea() * (max - min + 1));
}

function melanger<T>(t: T[], alea: Alea): void {
  for (let i = t.length - 1; i > 0; i--) {
    const j = entier(alea, 0, i);
    const tmp = t[i];
    t[i] = t[j];
    t[j] = tmp;
  }
}

function nouvelleCarteEnJeu(c: CarteSource, alea: Alea): CarteEnJeu {
  const fausses = c.wrongs.slice();
  melanger(fausses, alea);
  return { id: c.id, reponse: c.answer, montrees: fausses.slice(0, FAUSSES_AFFICHEES), reserve: fausses.slice(FAUSSES_AFFICHEES) };
}

function nombrePropositions(c: CarteEnJeu): number {
  return c.montrees.length + 1;
}

/** Propositions à présenter, mélangées à chaque passage. */
function propositions(c: CarteEnJeu, alea: Alea): string[] {
  const r = [c.reponse].concat(c.montrees);
  melanger(r, alea);
  return r;
}

/** Mauvaise réponse : 4 → 3 → 2 propositions, puis remplacement par la réserve. */
function affaiblir(c: CarteEnJeu, fausse: string): void {
  const i = c.montrees.indexOf(fausse);
  if (i < 0) throw new Error("Proposition inconnue : " + fausse);
  if (c.montrees.length > 1) {
    c.montrees.splice(i, 1);
  } else if (c.reserve.length > 0) {
    c.montrees[i] = c.reserve.shift() as string;
  }
}

function nouveauDuel(mainA: CarteSource[], mainB: CarteSource[], alea: Alea): EtatDuel {
  return {
    phase: "depart",
    mains: [mainA.map(function (c) { return nouvelleCarteEnJeu(c, alea); }), mainB.map(function (c) { return nouvelleCarteEnJeu(c, alea); })],
    detruites: [[], []],
    poseur: -1,
    gagnant: -1,
    jouee: null,
    indexJouee: -1,
    presentees: [],
  };
}

function commencerDuel(e: EtatDuel, joueur: number): void {
  if (e.phase !== "depart") throw new Error("Le duel a déjà commencé.");
  e.poseur = joueur;
  e.phase = "choisir";
}

function jouer(e: EtatDuel, index: number, alea: Alea): void {
  if (e.phase !== "choisir") throw new Error("Ce n'est pas le moment de poser une carte.");
  const main = e.mains[e.poseur];
  if (index < 0 || index >= main.length) throw new Error("Carte inconnue.");
  e.indexJouee = index;
  e.jouee = main.splice(index, 1)[0];
  e.presentees = propositions(e.jouee, alea);
  e.phase = "repondre";
}

function jouerAuHasard(e: EtatDuel, alea: Alea): number {
  const index = entier(alea, 0, e.mains[e.poseur].length - 1);
  jouer(e, index, alea);
  return index;
}

/** Bonne réponse : la carte est détruite. Mauvaise : elle revient affaiblie chez son propriétaire. */
function repondre(e: EtatDuel, choix: string): ResultatCoup {
  if (e.phase !== "repondre" || e.jouee === null) throw new Error("Aucune carte à deviner.");
  if (e.presentees.indexOf(choix) < 0) throw new Error("Réponse hors propositions : " + choix);
  const proprietaire = e.poseur;
  const carte = e.jouee;
  const juste = choix === carte.reponse;
  if (juste) {
    e.detruites[proprietaire].push(carte.id);
    if (e.mains[proprietaire].length === 0) e.gagnant = 1 - proprietaire;
  } else {
    affaiblir(carte, choix);
    e.mains[proprietaire].splice(e.indexJouee, 0, carte);
  }
  e.jouee = null;
  e.presentees = [];
  e.indexJouee = -1;
  if (e.gagnant !== -1) {
    e.phase = "finie";
  } else {
    e.poseur = 1 - proprietaire;
    e.phase = "choisir";
  }
  return { juste: juste, carte: carte.id, proprietaire: proprietaire, choix: choix };
}

/** Temps écoulé : compté comme une mauvaise réponse prise au hasard. */
function repondreTempsEcoule(e: EtatDuel, alea: Alea): ResultatCoup {
  if (e.jouee === null) throw new Error("Aucune carte à deviner.");
  const fausses = e.jouee.montrees;
  return repondre(e, fausses[entier(alea, 0, fausses.length - 1)]);
}

/** Cartes « Structure de la Bible » au plus par main : elles sont nombreuses et écraseraient le reste. */
const STRUCTURE_PAR_MAIN = 1;

/** Sert deux mains dans l'ordre donné, en limitant les cartes Structure tant que la réserve le permet. */
function composerMains(ordre: CarteSource[]): CarteSource[][] {
  const prises: boolean[] = [];
  const mains: CarteSource[][] = [[], []];
  mains.forEach(function (main) {
    let structure = 0;
    for (let i = 0; i < ordre.length && main.length < TAILLE_MAIN; i++) {
      const estStructure = ordre[i].category === "structure";
      if (prises[i] || (estStructure && structure >= STRUCTURE_PAR_MAIN)) continue;
      if (estStructure) structure++;
      prises[i] = true;
      main.push(ordre[i]);
    }
  });
  mains.forEach(function (main) {
    for (let i = 0; i < ordre.length && main.length < TAILLE_MAIN; i++) {
      if (!prises[i]) { prises[i] = true; main.push(ordre[i]); }
    }
  });
  return mains;
}

/** Deux mains sans doublon, en évitant les cartes vues récemment tant que la réserve le permet. */
function distribuer(reserve: CarteSource[], recentes: { [id: string]: boolean }, alea: Alea): CarteSource[][] {
  if (reserve.length < TAILLE_MAIN * 2) throw new Error("Pas assez de cartes.");
  const neuves = reserve.filter(function (c) { return !recentes[c.id]; });
  const vues = reserve.filter(function (c) { return !!recentes[c.id]; });
  melanger(neuves, alea);
  melanger(vues, alea);
  return composerMains(neuves.concat(vues));
}
