// Aventure en quiz (décision du 2026-11-28) : pour une étape (un récit) et une difficulté, le Scribe
// pose 10 questions de cette étape, l'une après l'autre. Chaque difficulté donne 0 à 3 étoiles selon le
// nombre de bonnes réponses ; on garde le meilleur résultat. Une étape s'ouvre avec au moins une étoile
// à l'étape précédente. Pas de mise : on gagne de l'XP par bonne réponse et des talents par étoile
// nouvelle. Le serveur tient la partie : le téléphone ne reçoit une réponse qu'après avoir répondu.
//
// Les questions d'une étape sont les cartes en ligne dont le récit (`story`) figure dans `recits` du
// niveau (data/aventure.json).
//
// RPC « aventure » { action, ... } :
//   etat                              → { etoiles, questions, seuils, enCours }
//   commencer { niveau, difficulte }  → { question }
//   question                          → { question } (la question en cours ; lance son délai)
//   repondre { choix }                → { juste, choix, bonne, reference, explication, fin? }
//   abandonner                        → {} (rien n'est gagné)

const CLE_QUIZ = "quiz";           // joueur / quiz : { etoiles: { "1": { lait: 2, manne: 0, solide: 0 } } }
const CLE_PARTIE_QUIZ = "partie";  // aventure / partie : la partie en cours (illisible par le joueur)
const COLLECTION_QUIZ = "aventure";
const PROPOSITIONS_QUIZ = 4;

// Réglables depuis le back-office (reglages.ts).
let QUIZ_QUESTIONS = 10;
let QUIZ_DELAI_S = 30;
let QUIZ_XP_BONNE = 3;
let QUIZ_TALENTS_ETOILE = 2;
let QUIZ_SEUILS: { [difficulte: string]: number[] } = { lait: [7, 9, 10], manne: [6, 8, 10], solide: [5, 8, 10] };

type EtoilesQuiz = { [niveau: string]: { [difficulte: string]: number } };

interface QuestionQuiz { id: string; propositions: string[]; }

interface PartieQuiz {
  niveau: number;
  difficulte: string;
  questions: QuestionQuiz[];
  index: number;      // question en cours
  bonnes: number;
  echeance: number;   // ms ; 0 = délai pas encore lancé
  repondue: boolean;  // la question en cours a sa réponse
  finie: boolean;
}

// ---------------------------------------------------------------- Règles pures (testées sans Nakama)

function niveauSource(niveau: number): NiveauSource | null {
  for (let i = 0; i < AVENTURE.chapitres.length; i++) {
    const n = AVENTURE.chapitres[i].niveaux.filter(function (x) { return x.id === niveau; })[0];
    if (n) return n;
  }
  return null;
}

/** Questions jouables d'une étape et d'une difficulté. */
function questionsDeLEtape(niveau: number, difficulte: string): CarteSource[] {
  const n = niveauSource(niveau);
  const recits = (n && n.recits) || [];
  return CARTES.filter(function (c) { return c.difficulty === difficulte && recits.indexOf(c.story || "") >= 0; });
}

/** Nombre de questions jouables par étape et difficulté. */
function nombreDeQuestions(): { [niveau: string]: { [difficulte: string]: number } } {
  const r: { [niveau: string]: { [difficulte: string]: number } } = {};
  AVENTURE.chapitres.forEach(function (ch) {
    ch.niveaux.forEach(function (n) {
      const d: { [difficulte: string]: number } = {};
      DIFFICULTES.forEach(function (x) { d[x] = questionsDeLEtape(n.id, x).length; });
      r[String(n.id)] = d;
    });
  });
  return r;
}

/** Étoiles (0 à 3) pour un nombre de bonnes réponses. Un seuil plus haut que le total devient le total. */
function etoilesPour(difficulte: string, bonnes: number): number {
  const seuils = QUIZ_SEUILS[difficulte] || [QUIZ_QUESTIONS];
  let n = 0;
  seuils.forEach(function (s) { if (bonnes >= Math.min(s, QUIZ_QUESTIONS)) n++; });
  return n;
}

function totalEtape(e: EtoilesQuiz, niveau: number): number {
  const d = e[String(niveau)] || {};
  return DIFFICULTES.reduce(function (n, x) { return n + (d[x] || 0); }, 0);
}

function etapeOuverte(e: EtoilesQuiz, niveau: number): boolean {
  if (niveauSource(niveau) === null) return false;
  return niveau === 1 || totalEtape(e, niveau - 1) > 0;
}

/** Ancienne progression (victoires contre le Scribe, une liste par niveau) : une étoile par victoire. */
function depuisAncienne(ancienne: { [niveau: string]: string[] } | null): EtoilesQuiz {
  const e: EtoilesQuiz = {};
  Object.keys(ancienne || {}).forEach(function (n) {
    const d: { [difficulte: string]: number } = {};
    ((ancienne as any)[n] || []).forEach(function (x: string) { if (DIFFICULTES.indexOf(x) >= 0) d[x] = 1; });
    if (Object.keys(d).length > 0) e[n] = d;
  });
  return e;
}

function nouvellePartieQuiz(niveau: number, difficulte: string, cartes: CarteSource[], alea: Alea): PartieQuiz {
  const tirees = cartes.slice();
  melanger(tirees, alea);
  return {
    niveau: niveau, difficulte: difficulte, index: 0, bonnes: 0, echeance: 0, repondue: false, finie: false,
    questions: tirees.slice(0, QUIZ_QUESTIONS).map(function (c) {
      const fausses = c.wrongs.slice();
      melanger(fausses, alea);
      const props = [c.answer].concat(fausses.slice(0, PROPOSITIONS_QUIZ - 1));
      melanger(props, alea);
      return { id: c.id, propositions: props };
    }),
  };
}

/** La question en cours, sans sa réponse ; lance son délai la première fois. */
function questionQuiz(p: PartieQuiz, maintenant: number): any {
  if (p.finie) throw refus("Cette partie est terminée.");
  if (p.repondue) throw refus("Réponds d'abord à la question en cours.");
  if (p.echeance === 0) p.echeance = maintenant + QUIZ_DELAI_S * 1000;
  const q = p.questions[p.index];
  const c = carteSource(q.id);
  return {
    numero: p.index + 1, total: p.questions.length, bonnes: p.bonnes,
    question: c ? c.question : "", category: c ? c.category : "", story: c ? c.story : "",
    propositions: q.propositions.slice(),
    temps: Math.max(0, Math.round((p.echeance - maintenant) / 1000)),
  };
}

/** Réponse à la question en cours ("" ou hors délai : temps écoulé, compté faux). */
function repondreQuiz(p: PartieQuiz, choix: string, maintenant: number): any {
  if (p.finie) throw refus("Cette partie est terminée.");
  if (p.repondue || p.echeance === 0) throw refus("Aucune question en cours.");
  const q = p.questions[p.index];
  if (choix !== "" && q.propositions.indexOf(choix) < 0) throw refus("Réponse inconnue.", nkruntime.Codes.INVALID_ARGUMENT);
  const c = carteSource(q.id);
  const bonne = c ? c.answer : "";
  const tempsEcoule = choix === "" || maintenant > p.echeance + MARGE_S * 1000;
  const juste = !tempsEcoule && choix === bonne;
  if (juste) p.bonnes++;
  p.repondue = true;
  if (p.index + 1 >= p.questions.length) {
    p.finie = true;
  } else {
    p.index++;
    p.repondue = false;
    p.echeance = 0;
  }
  return {
    juste: juste, choix: tempsEcoule ? "" : choix, tempsEcoule: tempsEcoule, bonne: bonne,
    reference: c ? c.reference : "", explication: c ? c.explanation : "",
    numero: p.finie ? p.questions.length : p.index, total: p.questions.length, bonnes: p.bonnes,
  };
}

// ---------------------------------------------------------------- Nakama

function etoilesQuizDe(nk: nkruntime.Nakama, userId: string): { valeur: EtoilesQuiz; version: string } {
  const lu = lireStockage(nk, userId, "joueur", CLE_QUIZ);
  if (lu.valeur) return { valeur: JSON.parse(JSON.stringify(lu.valeur.etoiles || {})), version: lu.version };
  // Première fois : on reprend les victoires de l'ancienne aventure contre le Scribe.
  const ancienne = progressionDe(nk, userId).valeur.etoiles;
  return { valeur: depuisAncienne(JSON.parse(JSON.stringify(ancienne || {}))), version: "*" };
}

const rpcAventure: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  chargerReglages(nk, logger);
  if (!ctx.userId) throw refus("Connexion requise.", nkruntime.Codes.UNAUTHENTICATED);
  const userId = ctx.userId;
  const d = payload ? JSON.parse(payload) : {};
  const action = String(d.action || "etat");
  const maintenant = Date.now();
  const lue = lireStockage(nk, userId, COLLECTION_QUIZ, CLE_PARTIE_QUIZ);
  const partie = lue.valeur ? (JSON.parse(JSON.stringify(lue.valeur)) as PartieQuiz) : null;
  const ecrirePartie = function (p: PartieQuiz) {
    nk.storageWrite([ecriture(userId, COLLECTION_QUIZ, CLE_PARTIE_QUIZ, p, lue.version, 0)]);
  };

  if (action === "etat") {
    return JSON.stringify({
      etoiles: etoilesQuizDe(nk, userId).valeur, questions: nombreDeQuestions(), minimum: QUIZ_QUESTIONS,
      seuils: QUIZ_SEUILS, enCours: !!partie && !partie.finie,
    });
  }

  if (action === "commencer") {
    const compte = nk.accountGetId(userId);
    if (!compte.email && !compte.user.googleId) throw refus("L'Aventure demande un compte.", nkruntime.Codes.PERMISSION_DENIED);
    const niveau = Number(d.niveau);
    const difficulte = String(d.difficulte);
    if (DIFFICULTES.indexOf(difficulte) < 0) throw refus("Difficulté inconnue.", nkruntime.Codes.INVALID_ARGUMENT);
    if (!etapeOuverte(etoilesQuizDe(nk, userId).valeur, niveau)) throw refus("Cette étape n'est pas encore ouverte.");
    const cartes = questionsDeLEtape(niveau, difficulte);
    if (cartes.length < QUIZ_QUESTIONS) throw refus("Cette étape n'a pas encore assez de questions dans cette difficulté.");
    const p = nouvellePartieQuiz(niveau, difficulte, cartes, Math.random);
    const q = questionQuiz(p, maintenant);
    ecrirePartie(p);
    return JSON.stringify({ question: q });
  }

  if (!partie) throw refus("Aucune partie d'Aventure en cours.");

  if (action === "question") {
    const q = questionQuiz(partie, maintenant);
    ecrirePartie(partie);
    return JSON.stringify({ question: q });
  }

  if (action === "abandonner") {
    partie.finie = true;
    ecrirePartie(partie);
    return JSON.stringify({});
  }

  if (action !== "repondre") throw refus("Action inconnue : " + action, nkruntime.Codes.INVALID_ARGUMENT);
  const r = repondreQuiz(partie, String(d.choix || ""), maintenant);
  if (!partie.finie) {
    ecrirePartie(partie);
    return JSON.stringify(r);
  }

  // Fin : étoiles (meilleur résultat gardé), XP par bonne réponse, talents par étoile nouvelle.
  const e = etoilesQuizDe(nk, userId);
  const avant = (e.valeur[String(partie.niveau)] || {})[partie.difficulte] || 0;
  const obtenues = etoilesPour(partie.difficulte, partie.bonnes);
  const meilleur = Math.max(avant, obtenues);
  const parNiveau = e.valeur[String(partie.niveau)] || {};
  parNiveau[partie.difficulte] = meilleur;
  e.valeur[String(partie.niveau)] = parNiveau;
  const xp = partie.bonnes * QUIZ_XP_BONNE;
  const talents = (meilleur - avant) * QUIZ_TALENTS_ETOILE;
  const xpAvant = xpDe(nk, userId);
  const changeset: { [cle: string]: number } = {};
  if (xp > 0) changeset["xp"] = xp;
  if (talents > 0) changeset["talents"] = talents;
  try {
    nk.multiUpdate(null, [
      ecriture(userId, COLLECTION_QUIZ, CLE_PARTIE_QUIZ, partie, lue.version, 0),
      ecriture(userId, "joueur", CLE_QUIZ, { etoiles: e.valeur }, e.version, 1),
    ], null, Object.keys(changeset).length > 0
      ? [{ userId: userId, changeset: changeset, metadata: { raison: "aventure", niveau: partie.niveau, difficulte: partie.difficulte, bonnes: partie.bonnes } }]
      : [], true);
  } catch (err) {
    logger.warn("Aventure : fin refusée pour %s : %s", userId, String(err));
    throw refus("Cette réponse a déjà été comptée.", nkruntime.Codes.ABORTED);
  }
  const xpTotal = xpDe(nk, userId);
  if (xp > 0) inscrireClassement(nk, logger, userId, xpTotal);
  r.fin = {
    bonnes: partie.bonnes, total: partie.questions.length, etoiles: obtenues, meilleur: meilleur,
    nouvelles: meilleur - avant, xp: xp, talents: talents, talentsTotal: talentsDe(nk, userId), xpTotal: xpTotal,
    niveauAvant: niveauDepuisXp(xpAvant).niveau, niveau: niveauDepuisXp(xpTotal).niveau, progression: e.valeur,
  };
  return JSON.stringify(r);
};
