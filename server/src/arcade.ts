// Arcade solo contre le Scribe (PRD §3.1), jouée sur le serveur : le client envoie ses choix,
// le serveur tire les cartes, fait jouer l'IA, tient les délais et règle la mise.
//
// RPC « arcade », charge utile { action, ... } :
//   etat                          → progression (étoiles par niveau), talents, contenu des niveaux
//   commencer { niveau, difficulte } → prélève la mise, distribue, pose la question de départ
//   depart { choix }              → règle la question de départ ("" = temps écoulé)
//   suite                         → coup suivant : l'IA pose sa carte, ou c'est au joueur de choisir
//   jouer { index }               → le joueur pose une carte (-1 = temps écoulé), l'IA y répond
//   repondre { choix }            → le joueur répond à la carte de l'IA ("" = temps écoulé)
//   abandonner                    → défaite immédiate, la mise est perdue
// La mise est prélevée au départ ; le gagnant reçoit les deux mises. Le joueur est l'indice 0
// du duel, l'IA l'indice 1.

const COLLECTION_ARCADE = "arcade";
const COLLECTION_PARTIES = "parties";  // cartes des dernières parties, communes à l'arcade et aux duels
const CLE_PARTIE = "partie";
const CLE_RECENTES = "recentes";
const CLE_AVENTURE = "aventure";
let DELAI_DEPART_S = 20;
let DELAI_CHOISIR_S = 20;
let DELAI_REPONDRE_S = 30;
/** Délai accordé en plus pour le réseau avant de jouer à la place du joueur. */
const MARGE_S = 3;
const PARTIES_RECENTES = 5;
const CLASSEMENT_XP = "xp";
const DIFFICULTES = ["lait", "manne", "solide"];

interface DepartArcade { id: string; propositions: string[]; reponse: string; debut: number; iaTemps: number; iaJuste: boolean; }

interface PartieArcade {
  etape: string;               // "depart", "suite", "choisir", "repondre" ou "finie"
  niveau: number;
  difficulte: string;
  mise: number;
  duel: EtatDuel;
  depart: DepartArcade | null;
  echeance: number;            // ms ; au-delà (plus la marge), le serveur joue à la place du joueur
  memoire: MemoireIA;
}

interface ProgressionAventure { etoiles: { [niveau: string]: string[] }; }

/** Erreur renvoyée au joueur (message lisible). */
function refus(message: string, code?: number): nkruntime.Error {
  return { message: message, code: code === undefined ? nkruntime.Codes.FAILED_PRECONDITION : code } as nkruntime.Error;
}

// ---------------------------------------------------------------- Règles pures (testées sans Nakama)

function chapitreDuNiveau(niveau: number): ChapitreSource | null {
  for (let i = 0; i < AVENTURE.chapitres.length; i++) {
    const ch = AVENTURE.chapitres[i];
    for (let j = 0; j < ch.niveaux.length; j++) {
      if (ch.niveaux[j].id === niveau) return ch;
    }
  }
  return null;
}

/** Un niveau est ouvert si c'est le premier, ou si le précédent a au moins une étoile. */
function niveauOuvert(p: ProgressionAventure, niveau: number): boolean {
  if (chapitreDuNiveau(niveau) === null) return false;
  if (niveau === 1) return true;
  const avant = p.etoiles[String(niveau - 1)];
  return !!avant && avant.length > 0;
}

function cartesDuChapitre(niveau: number, difficulte: string): CarteSource[] | null {
  const ch = chapitreDuNiveau(niveau);
  if (ch === null) return null;
  const duChapitre = CARTES.filter(function (c) {
    return c.difficulty === difficulte && c.books.some(function (b) { return ch.livres.indexOf(b) >= 0; });
  });
  return duChapitre.length >= TAILLE_MAIN * 2 ? duChapitre : null;
}

/** Cartes du niveau : les livres du chapitre, ou toute la Bible si elles ne suffisent pas encore. */
function reserveDuNiveau(niveau: number, difficulte: string): CarteSource[] {
  const duChapitre = cartesDuChapitre(niveau, difficulte);
  return duChapitre !== null ? duChapitre : CARTES.filter(function (c) { return c.difficulty === difficulte; });
}

/** Pour chaque niveau et difficulté : vrai si les livres du chapitre suffisent (sinon toute la Bible). */
function contenuDesNiveaux(): { [niveau: string]: { [difficulte: string]: boolean } } {
  const r: { [niveau: string]: { [difficulte: string]: boolean } } = {};
  AVENTURE.chapitres.forEach(function (ch) {
    ch.niveaux.forEach(function (n) {
      const parDifficulte: { [difficulte: string]: boolean } = {};
      DIFFICULTES.forEach(function (d) {
        parDifficulte[d] = cartesDuChapitre(n.id, d) !== null;
      });
      r[String(n.id)] = parDifficulte;
    });
  });
  return r;
}

// La réserve en ligne n'est pas dans l'APK : le serveur envoie le texte des cartes. Le client ne
// reçoit la réponse que pour ses propres cartes, ou pour une carte de l'IA qu'il vient de trouver.

function carteSource(id: string): CarteSource | null {
  for (let i = 0; i < CARTES.length; i++) {
    if (CARTES[i].id === id) return CARTES[i];
  }
  return null;
}

/** Carte entière, réponse comprise (même format que data/cartes.json). */
function carteComplete(id: string): any {
  const c = carteSource(id);
  if (c === null) return { id: id };
  return {
    id: c.id, difficulty: c.difficulty, testament: c.testament, books: c.books, category: c.category,
    question: c.question, answer: c.answer, wrongs: c.wrongs, reference: c.reference,
    explanation: c.explanation, story: c.story,
  };
}

/** Carte à deviner : la question et ses propositions, sans identifiant ni réponse. */
function carteADeviner(id: string, presentees: string[]): any {
  const c = carteSource(id);
  return {
    difficulty: c ? c.difficulty : "", category: c ? c.category : "", question: c ? c.question : "",
    story: c ? c.story : "", propositions: presentees.slice(),
  };
}

function questionDepart(id: string): string {
  for (let i = 0; i < QUESTIONS_DEPART.length; i++) {
    if (QUESTIONS_DEPART[i].id === id) return QUESTIONS_DEPART[i].question || "";
  }
  return "";
}

/** Ajoute l'étoile de la difficulté gagnée ; renvoie vrai si elle est nouvelle. */
function ajouterEtoile(p: ProgressionAventure, niveau: number, difficulte: string): boolean {
  const cle = String(niveau);
  const liste = p.etoiles[cle] || [];
  if (liste.indexOf(difficulte) >= 0) return false;
  liste.push(difficulte);
  p.etoiles[cle] = liste;
  return true;
}

function nouvellePartie(niveau: number, difficulte: string, recentes: { [id: string]: boolean }, maintenant: number, alea: Alea): PartieArcade {
  const mains = distribuer(reserveDuNiveau(niveau, difficulte), recentes, alea);
  const partie: PartieArcade = {
    etape: "depart",
    niveau: niveau,
    difficulte: difficulte,
    mise: mise("arcade", difficulte),
    duel: nouveauDuel(mains[0], mains[1], alea),
    depart: null,
    echeance: 0,
    memoire: {},
  };
  poserQuestionDepart(partie, maintenant, alea);
  return partie;
}

function poserQuestionDepart(partie: PartieArcade, maintenant: number, alea: Alea): void {
  const q = QUESTIONS_DEPART[entier(alea, 0, QUESTIONS_DEPART.length - 1)];
  const props = [q.answer].concat(q.wrongs);
  melanger(props, alea);
  partie.depart = {
    id: q.id,
    propositions: props,
    reponse: q.answer,
    debut: maintenant,
    iaTemps: DEPART_IA_MIN_S * 1000 + alea() * (DEPART_IA_MAX_S - DEPART_IA_MIN_S) * 1000,
    iaJuste: alea() < CHANCE_DEPART_IA,
  };
  partie.etape = "depart";
  partie.echeance = maintenant + DELAI_DEPART_S * 1000;
}

/**
 * Question de départ : le premier qui répond décide (juste → il commence, faux → l'autre).
 * choix "" : le joueur n'a pas répondu à temps.
 */
function reglerDepart(partie: PartieArcade, choix: string, maintenant: number, alea: Alea): any {
  if (partie.etape !== "depart" || partie.depart === null) throw refus("Pas de question de départ en cours.");
  const d = partie.depart;
  if (choix !== "" && d.propositions.indexOf(choix) < 0) throw refus("Réponse inconnue.");
  const ecoule = maintenant - d.debut;
  const aTemps = choix !== "" && ecoule <= (DELAI_DEPART_S + MARGE_S) * 1000;
  const tempsJoueur = aTemps ? ecoule : Infinity;
  let commence: number;
  let iaPremiere = false;
  if (d.iaTemps < tempsJoueur && d.iaTemps <= DELAI_DEPART_S * 1000) {
    iaPremiere = true;
    commence = d.iaJuste ? 1 : 0;
  } else if (aTemps) {
    commence = choix === d.reponse ? 0 : 1;
  } else {
    // Personne n'a répondu : nouvelle question.
    poserQuestionDepart(partie, maintenant, alea);
    return { nouvelle: true };
  }
  const resultat = {
    commence: commence,
    iaPremiere: iaPremiere,
    iaJuste: d.iaJuste,
    iaTemps: Math.round(d.iaTemps / 100) / 10,
    bonne: d.reponse,
    choix: aTemps ? choix : "",
  };
  commencerDuel(partie.duel, commence);
  partie.depart = null;
  partie.etape = "suite";
  partie.echeance = 0;
  return resultat;
}

/** Coup suivant : l'IA pose sa carte, ou le joueur a 10 s pour choisir la sienne. */
function suiteArcade(partie: PartieArcade, maintenant: number, alea: Alea): any {
  if (partie.etape !== "suite") throw refus("Rien à poursuivre.");
  const duel = partie.duel;
  if (duel.poseur === 1) {
    const index = carteIA(duel.mains[1], alea);
    jouer(duel, index, alea);
    partie.etape = "repondre";
    partie.echeance = maintenant + DELAI_REPONDRE_S * 1000;
    return { ia: { index: index } };
  }
  partie.etape = "choisir";
  partie.echeance = maintenant + DELAI_CHOISIR_S * 1000;
  return {};
}

/** Le joueur pose une carte (index -1 ou délai dépassé : au hasard), puis l'IA y répond. */
function jouerArcade(partie: PartieArcade, index: number, maintenant: number, alea: Alea): any {
  if (partie.etape !== "choisir") throw refus("Ce n'est pas à toi de poser une carte.");
  const duel = partie.duel;
  const enRetard = maintenant > partie.echeance + MARGE_S * 1000;
  let auHasard = false;
  if (enRetard || index < 0 || index >= duel.mains[0].length) {
    index = jouerAuHasard(duel, alea);
    auHasard = true;
  } else {
    jouer(duel, index, alea);
  }
  const carte = duel.jouee as CarteEnJeu;
  const presentees = duel.presentees.slice();
  const choixIA = reponseIA(carte.id, presentees, carte.reponse, partie.difficulte, partie.memoire, alea);
  const r = repondre(duel, choixIA);
  partie.etape = duel.phase === "finie" ? "finie" : "suite";
  partie.echeance = 0;
  return { coup: { index: index, auHasard: auHasard, carte: carteComplete(r.carte), presentees: presentees, choix: choixIA, juste: r.juste } };
}

/** Le joueur répond à la carte de l'IA ("" ou délai dépassé : temps écoulé). */
function repondreArcade(partie: PartieArcade, choix: string, maintenant: number, alea: Alea): any {
  if (partie.etape !== "repondre") throw refus("Aucune carte à deviner.");
  const duel = partie.duel;
  if (choix !== "" && duel.presentees.indexOf(choix) < 0) throw refus("Réponse inconnue.");
  const enRetard = maintenant > partie.echeance + MARGE_S * 1000;
  const tempsEcoule = enRetard || choix === "";
  const r = tempsEcoule ? repondreTempsEcoule(duel, alea) : repondre(duel, choix);
  partie.etape = duel.phase === "finie" ? "finie" : "suite";
  partie.echeance = 0;
  // La réponse d'une carte ratée reste secrète (PRD §2.5).
  return { coup: { carte: r.juste ? carteComplete(r.carte) : null, choix: tempsEcoule ? "" : choix, juste: r.juste, tempsEcoule: tempsEcoule } };
}

function abandonnerArcade(partie: PartieArcade): void {
  if (partie.etape === "finie") return;
  partie.duel.gagnant = 1;
  partie.duel.phase = "finie";
  partie.etape = "finie";
}

/** Ce que le joueur voit : ses cartes, le nombre de cartes de l'IA, la carte à deviner. */
function vueArcade(partie: PartieArcade, maintenant: number): any {
  const duel = partie.duel;
  const restant = partie.echeance > 0 ? Math.max(0, Math.round((partie.echeance - maintenant) / 1000)) : 0;
  return {
    etape: partie.etape,
    niveau: partie.niveau,
    difficulte: partie.difficulte,
    mise: partie.mise,
    poseur: duel.poseur,
    gagnant: duel.gagnant,
    main: duel.mains[0].map(function (c) { return { carte: carteComplete(c.id), fausses: c.montrees.slice(), reserve: c.reserve.length }; }),
    mainIA: duel.mains[1].length,
    carte: partie.etape === "repondre" && duel.jouee ? carteADeviner(duel.jouee.id, duel.presentees) : null,
    depart: partie.etape === "depart" && partie.depart ? { question: questionDepart(partie.depart.id), propositions: partie.depart.propositions.slice() } : null,
    // Cartes détruites : toutes trouvées, donc révélées aux deux joueurs.
    detruites: [duel.detruites[0].map(carteComplete), duel.detruites[1].map(carteComplete)],
    temps: restant,
  };
}

// ---------------------------------------------------------------- Nakama

function lireStockage(nk: nkruntime.Nakama, userId: string, collection: string, cle: string): { valeur: any; version: string } {
  const lus = nk.storageRead([{ collection: collection, key: cle, userId: userId }]);
  return lus.length > 0 ? { valeur: lus[0].value, version: lus[0].version } : { valeur: null, version: "*" };
}

function ecriture(userId: string, collection: string, cle: string, valeur: any, version: string, lecture: nkruntime.ReadPermissionValues): nkruntime.StorageWriteRequest {
  return { collection: collection, key: cle, userId: userId, value: valeur, version: version, permissionRead: lecture, permissionWrite: 0 };
}

/** Cartes des dernières parties (tous modes en ligne), à éviter au tirage (PRD §2.1). */
function cartesRecentes(valeurs: any[]): { [id: string]: boolean } {
  const recentes: { [id: string]: boolean } = {};
  valeurs.forEach(function (v) {
    const parties: string[][] = (v && v.parties) || [];
    parties.forEach(function (ids) { ids.forEach(function (id) { recentes[id] = true; }); });
  });
  return recentes;
}

/** Ajoute les cartes d'une partie qui commence aux 5 dernières parties du joueur. */
function ecritureRecentes(userId: string, lue: { valeur: any; version: string }, duel: EtatDuel): nkruntime.StorageWriteRequest {
  const parties: string[][] = (lue.valeur && lue.valeur.parties) || [];
  const ids = duel.mains[0].concat(duel.mains[1]).map(function (c) { return c.id; });
  return ecriture(userId, COLLECTION_PARTIES, CLE_RECENTES, { parties: [ids].concat(parties).slice(0, PARTIES_RECENTES) }, lue.version, 0);
}

function talentsDe(nk: nkruntime.Nakama, userId: string): number {
  const compte = nk.accountGetId(userId);
  return (compte.wallet && compte.wallet["talents"]) || 0;
}

function xpDe(nk: nkruntime.Nakama, userId: string): number {
  const compte = nk.accountGetId(userId);
  return (compte.wallet && compte.wallet["xp"]) || 0;
}

/** Classement général par XP (PRD §7) : le score est l'XP totale du joueur. */
function inscrireClassement(nk: nkruntime.Nakama, logger: nkruntime.Logger, userId: string, xp: number): void {
  try {
    const compte = nk.accountGetId(userId);
    nk.leaderboardRecordWrite(CLASSEMENT_XP, userId, compte.user.username, xp, 0, undefined, nkruntime.OverrideOperator.SET);
  } catch (e) {
    logger.warn("Classement XP : écriture refusée pour %s : %s", userId, String(e));
  }
}

function progressionDe(nk: nkruntime.Nakama, userId: string): { valeur: ProgressionAventure; version: string } {
  const lu = lireStockage(nk, userId, "joueur", CLE_AVENTURE);
  return { valeur: lu.valeur || { etoiles: {} }, version: lu.version };
}

const rpcArcade: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  chargerReglages(nk, logger);
  if (!ctx.userId) throw refus("Connexion requise.", nkruntime.Codes.UNAUTHENTICATED);
  const userId = ctx.userId;
  const demande = payload ? JSON.parse(payload) : {};
  const action: string = demande.action || "etat";
  const maintenant = Date.now();
  const alea: Alea = Math.random;

  if (action === "etat") {
    const lue = lireStockage(nk, userId, COLLECTION_ARCADE, CLE_PARTIE);
    return JSON.stringify({
      talents: talentsDe(nk, userId),
      etoiles: progressionDe(nk, userId).valeur.etoiles,
      enCours: !!lue.valeur && lue.valeur.etape !== "finie",
      duChapitre: contenuDesNiveaux(),
    });
  }

  if (action === "commencer") {
    const compte = nk.accountGetId(userId);
    if (!compte.email && !compte.user.googleId) throw refus("L'arcade demande un compte.", nkruntime.Codes.PERMISSION_DENIED);
    const niveau = Number(demande.niveau);
    const difficulte = String(demande.difficulte);
    if (DIFFICULTES.indexOf(difficulte) < 0) throw refus("Difficulté inconnue.", nkruntime.Codes.INVALID_ARGUMENT);
    if (!niveauOuvert(progressionDe(nk, userId).valeur, niveau)) throw refus("Ce niveau n'est pas encore ouvert.");
    const somme = mise("arcade", difficulte);
    if (((compte.wallet && compte.wallet["talents"]) || 0) < somme) throw refus("Pas assez de talents pour cette difficulté.");
    const rec = lireStockage(nk, userId, COLLECTION_PARTIES, CLE_RECENTES);
    const partie = nouvellePartie(niveau, difficulte, cartesRecentes([rec.valeur]), maintenant, alea);
    const precedente = lireStockage(nk, userId, COLLECTION_ARCADE, CLE_PARTIE);
    // Une partie laissée en cours est perdue : sa mise a déjà été prélevée.
    nk.multiUpdate(null, [
      ecriture(userId, COLLECTION_ARCADE, CLE_PARTIE, partie, precedente.version, 0),
      ecritureRecentes(userId, rec, partie.duel),
    ], null, [{ userId: userId, changeset: { talents: -somme }, metadata: { raison: "mise_arcade", niveau: niveau, difficulte: difficulte } }], true);
    return JSON.stringify({ vue: vueArcade(partie, maintenant), talents: talentsDe(nk, userId) });
  }

  const lue = lireStockage(nk, userId, COLLECTION_ARCADE, CLE_PARTIE);
  if (!lue.valeur) throw refus("Aucune partie d'arcade en cours.");
  const partie = lue.valeur as PartieArcade;
  const dejaFinie = partie.etape === "finie";
  if (dejaFinie && action !== "abandonner") throw refus("Cette partie est terminée.");
  let reponse: any;
  switch (action) {
    case "depart": reponse = reglerDepart(partie, String(demande.choix || ""), maintenant, alea); break;
    case "suite": reponse = suiteArcade(partie, maintenant, alea); break;
    case "jouer": reponse = jouerArcade(partie, Number(demande.index), maintenant, alea); break;
    case "repondre": reponse = repondreArcade(partie, String(demande.choix || ""), maintenant, alea); break;
    case "abandonner": abandonnerArcade(partie); reponse = {}; break;
    default: throw refus("Action inconnue : " + action, nkruntime.Codes.INVALID_ARGUMENT);
  }

  const ecritures = [ecriture(userId, COLLECTION_ARCADE, CLE_PARTIE, partie, lue.version, 0)];
  const portefeuille: nkruntime.WalletUpdate[] = [];
  if (dejaFinie) return JSON.stringify({ vue: vueArcade(partie, maintenant) });
  let xpAvant = 0;
  if (partie.etape === "finie") {
    const gagne = partie.duel.gagnant === 0;
    const xp = xpDePartie(gagne, action === "abandonner");
    xpAvant = xpDe(nk, userId);
    let nouvelleEtoile = false;
    const meta = { niveau: partie.niveau, difficulte: partie.difficulte };
    if (gagne) {
      const prog = progressionDe(nk, userId);
      nouvelleEtoile = ajouterEtoile(prog.valeur, partie.niveau, partie.difficulte);
      ecritures.push(ecriture(userId, "joueur", CLE_AVENTURE, prog.valeur, prog.version, 1));
      portefeuille.push({ userId: userId, changeset: { talents: partie.mise * 2, xp: xp }, metadata: { raison: "gain_arcade", niveau: meta.niveau, difficulte: meta.difficulte } });
    } else if (xp > 0) {
      portefeuille.push({ userId: userId, changeset: { xp: xp }, metadata: { raison: "xp_arcade", niveau: meta.niveau, difficulte: meta.difficulte } });
    }
    reponse.fin = { gagne: gagne, gain: gagne ? partie.mise : -partie.mise, nouvelleEtoile: nouvelleEtoile, xp: xp };
  }
  try {
    nk.multiUpdate(null, ecritures, null, portefeuille, true);
  } catch (e) {
    // Deux appels simultanés : le premier a déjà joué ce coup.
    logger.warn("Arcade : écriture refusée pour %s : %s", userId, String(e));
    throw refus("Ce coup a déjà été joué.", nkruntime.Codes.ABORTED);
  }
  reponse.vue = vueArcade(partie, maintenant);
  if (reponse.fin) {
    reponse.fin.talents = talentsDe(nk, userId);
    reponse.fin.etoiles = progressionDe(nk, userId).valeur.etoiles[String(partie.niveau)] || [];
    const xpTotal = xpDe(nk, userId);
    reponse.fin.xpTotal = xpTotal;
    reponse.fin.niveauAvant = niveauDepuisXp(xpAvant).niveau;
    reponse.fin.niveau = niveauDepuisXp(xpTotal).niveau;
    if (reponse.fin.xp > 0) inscrireClassement(nk, logger, userId, xpTotal);
  }
  return JSON.stringify(reponse);
};
