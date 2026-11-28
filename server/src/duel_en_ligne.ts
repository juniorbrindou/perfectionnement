// Duels en ligne entre deux joueurs (PRD §2, §3.3, §3.4, §4) : partie gérée par le serveur (« match »
// autoritatif Nakama, module « duel »).
//
// - Duel rapide : le client entre dans le matchmaker avec la propriété `difficulte` (requête
//   « +properties.difficulte:lait ») ; le hook apresAppariement crée la partie pour les deux joueurs.
// - Entre amis : RPC « duel_ami » { action: "creer", difficulte } → { matchId, code } ;
//   { action: "voir", code } → { matchId, difficulte, mise, createur } ; puis le client rejoint la partie.
//
// Messages du client (op code, données JSON) :
//   1 DEPART { choix }   2 JOUER { index }   3 REPONDRE { choix }   4 CONTINUER
//   5 ABANDONNER         6 REVANCHE { accepte }
// Le serveur envoie à chaque joueur sa propre vue (op 10) après chaque changement.
//
// La logique est écrite en fonctions pures sur l'état (testées sans Nakama) ; les fonctions
// duel* du bas l'appliquent dans Nakama (portefeuilles, stockage, messages).

const MODULE_DUEL = "duel";
const OP_DEPART = 1;
const OP_JOUER = 2;
const OP_REPONDRE = 3;
const OP_CONTINUER = 4;
const OP_ABANDONNER = 5;
const OP_REVANCHE = 6;
const OP_VUE = 10;

let DUEL_DEPART_S = 30;       // en ligne, trois fois les délais d'origine (10, 10, 15 s) :
let DUEL_CHOISIR_S = 30;      // les joueurs trouvaient le temps trop court
let DUEL_REPONDRE_S = 45;
const ANNONCE_S = 3;            // résultat de la question de départ, avant le premier tour
let RESULTAT_S = 10;          // écran de résultat d'un coup, si les deux n'ont pas touché « Continuer »
let RECONNEXION_S = 30;       // PRD §3.4
let REVANCHE_S = 15;
const ARRIVEE_S = 20;           // duel rapide : les deux joueurs doivent arriver dans ce délai
const ATTENTE_AMI_S = 10 * 60;  // une partie entre amis attend son invité au plus 10 minutes
const MARGE_DIRECT_MS = 1000;   // retard réseau toléré avant de jouer à la place d'un joueur
const TICS_PAR_SECONDE = 5;
const ALPHABET_CODE = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const LONGUEUR_CODE = 6;

interface JoueurDuel { userId: string; pseudo: string; niveau: number; present: boolean; absentDepuis: number; }

interface FinDuel {
  gagnant: number;
  raison: string;   // "cartes", "abandon" ou "deconnexion"
  xp: number[];
  comptes: any[];   // après règlement : { talents, xpTotal, niveauAvant, niveau } par joueur
}

interface PartieDuel {
  mode: string;          // "rapide", "ami" ou "salon"
  salon: string;         // identifiant du salon (mode "salon"), sinon ""
  contenu: ContenuSalon | null; // cartes du salon
  code: string;
  difficulte: string;
  mise: number;
  createur: string;
  pseudoCreateur: string;
  attendus: string[];    // duel rapide : les deux joueurs trouvés par le matchmaker
  etape: string;         // attente, depart, annonce, choisir, repondre, resultat, finie, annulee
  joueurs: JoueurDuel[]; // indices du duel, dans l'ordre d'arrivée
  duel: EtatDuel | null;
  depart: { id: string; propositions: string[]; reponse: string } | null;
  echeance: number;      // ms ; 0 = pas de délai
  pauseReste: number;    // ms du délai en cours gelés pendant une déconnexion, -1 sinon
  coup: any;             // dernier événement, montré dans les vues
  continuer: boolean[];
  revanche: boolean[];
  fin: FinDuel | null;
  misesPrelevees: boolean;
  raisonAnnulation: string;
  creee: number;
  version: number;       // augmente à chaque changement : il faut alors renvoyer les vues
  presences: { [userId: string]: nkruntime.Presence };
}

interface EffetDuel { type: string; }  // demarrer, regler, rembourser, revanche, terminer

// ---------------------------------------------------------------- Règles pures

function nouvellePartieDuel(mode: string, difficulte: string, code: string, createur: string, attendus: string[], maintenant: number): PartieDuel {
  return {
    mode: mode, salon: "", contenu: null, code: code, difficulte: difficulte, mise: mise("duel", difficulte), createur: createur,
    pseudoCreateur: "", attendus: attendus, etape: "attente", joueurs: [], duel: null, depart: null,
    echeance: 0, pauseReste: -1, coup: null, continuer: [false, false], revanche: [false, false],
    fin: null, misesPrelevees: false, raisonAnnulation: "", creee: maintenant, version: 0, presences: {},
  };
}

function nouveauCode(alea: Alea): string {
  let code = "";
  for (let i = 0; i < LONGUEUR_CODE; i++) code += ALPHABET_CODE.charAt(entier(alea, 0, ALPHABET_CODE.length - 1));
  return code;
}

function indexJoueur(p: PartieDuel, userId: string): number {
  for (let i = 0; i < p.joueurs.length; i++) {
    if (p.joueurs[i].userId === userId) return i;
  }
  return -1;
}

/** Partie en cours de jeu : une déconnexion la met en pause. */
function enJeu(p: PartieDuel): boolean {
  return p.fin === null && ["depart", "annonce", "choisir", "repondre", "resultat"].indexOf(p.etape) >= 0;
}

function absents(p: PartieDuel): number[] {
  const r: number[] = [];
  p.joueurs.forEach(function (j, i) { if (!j.present) r.push(i); });
  return r;
}

/** "" si le joueur peut entrer dans la partie, sinon la raison du refus. */
function accepterArrivee(p: PartieDuel, userId: string): string {
  if (p.etape === "annulee") return "Cette partie a été annulée.";
  if (indexJoueur(p, userId) >= 0) return "";  // retour après une déconnexion
  if (p.etape !== "attente") return "La partie a déjà commencé.";
  if (p.joueurs.length >= 2) return "La partie est complète.";
  if (p.mode === "rapide" && p.attendus.indexOf(userId) < 0) return "Cette partie ne t'attend pas.";
  if (p.mode === "ami" && p.joueurs.length === 0 && userId !== p.createur) return "La partie n'est pas encore ouverte.";
  return "";
}

/** Un joueur entre (ou revient). Renvoie [demarrer] quand les deux joueurs sont là. */
function arriveeDuel(p: PartieDuel, userId: string, pseudo: string, niveau: number, maintenant: number): EffetDuel[] {
  const i = indexJoueur(p, userId);
  p.version++;
  if (i >= 0) {
    p.joueurs[i].present = true;
    p.joueurs[i].absentDepuis = 0;
    if (absents(p).length === 0 && p.pauseReste >= 0) {
      p.echeance = p.echeance > 0 ? maintenant + p.pauseReste : 0;
      p.pauseReste = -1;
    }
    return [];
  }
  p.joueurs.push({ userId: userId, pseudo: pseudo, niveau: niveau, present: true, absentDepuis: 0 });
  return p.joueurs.length === 2 && p.etape === "attente" ? [{ type: "demarrer" }] : [];
}

function annulerDuel(p: PartieDuel, raison: string): EffetDuel[] {
  const effets: EffetDuel[] = [];
  if (p.misesPrelevees) effets.push({ type: "rembourser" });
  p.misesPrelevees = false;
  p.etape = "annulee";
  p.raisonAnnulation = raison;
  p.echeance = 0;
  p.version++;
  effets.push({ type: "terminer" });
  return effets;
}

/** Les mises sont prélevées : on distribue et on pose la question de départ. */
function demarrerDuel(p: PartieDuel, recentes: { [id: string]: boolean }, maintenant: number, alea: Alea): void {
  // Un salon joue sur son contenu ; s'il ne suffit plus (cartes retirées), sur toute la difficulté.
  let reserve = CARTES.filter(function (c) { return p.contenu !== null && carteDuSalon(c, p.difficulte, p.contenu); });
  if (reserve.length < TAILLE_MAIN * 2) reserve = CARTES.filter(function (c) { return c.difficulty === p.difficulte; });
  const mains = distribuer(reserve, recentes, alea);
  p.duel = nouveauDuel(mains[0], mains[1], alea);
  p.fin = null;
  p.coup = null;
  p.continuer = [false, false];
  p.revanche = [false, false];
  p.pauseReste = -1;
  p.misesPrelevees = true;
  poserQuestionDepartDuel(p, maintenant, alea);
}

function poserQuestionDepartDuel(p: PartieDuel, maintenant: number, alea: Alea): void {
  const q = QUESTIONS_DEPART[entier(alea, 0, QUESTIONS_DEPART.length - 1)];
  const props = [q.answer].concat(q.wrongs);
  melanger(props, alea);
  p.depart = { id: q.id, propositions: props, reponse: q.answer };
  p.etape = "depart";
  p.echeance = maintenant + DUEL_DEPART_S * 1000;
  p.version++;
}

/** Fin de la partie : le perdant gagne 10 XP s'il a perdu ses cartes, rien s'il a abandonné ou quitté. */
function terminerDuel(p: PartieDuel, gagnant: number, raison: string, maintenant: number): EffetDuel[] {
  const xp = [0, 0];
  xp[gagnant] = XP_VICTOIRE;
  xp[1 - gagnant] = raison === "cartes" ? XP_DEFAITE : 0;
  p.fin = { gagnant: gagnant, raison: raison, xp: xp, comptes: [null, null] };
  if (raison !== "cartes") ouvrirRevanche(p, maintenant);
  p.version++;
  return [{ type: "regler" }];
}

function ouvrirRevanche(p: PartieDuel, maintenant: number): void {
  p.etape = "finie";
  p.echeance = maintenant + REVANCHE_S * 1000;
  p.revanche = [false, false];
  p.pauseReste = -1;
}

/** Après l'écran de résultat : tour suivant, ou fin de partie. */
function suivantDuel(p: PartieDuel, maintenant: number): void {
  if (p.fin !== null) {
    ouvrirRevanche(p, maintenant);
  } else {
    p.etape = "choisir";
    p.echeance = maintenant + DUEL_CHOISIR_S * 1000;
  }
  p.coup = p.fin !== null ? p.coup : null;
  p.version++;
}

function poserCarteDuel(p: PartieDuel, index: number, auHasard: boolean, maintenant: number, alea: Alea): void {
  const duel = p.duel as EtatDuel;
  if (auHasard) index = jouerAuHasard(duel, alea);
  else jouer(duel, index, alea);
  p.coup = { type: "pose", poseur: duel.poseur, auHasard: auHasard };
  p.etape = "repondre";
  p.echeance = maintenant + DUEL_REPONDRE_S * 1000;
  p.version++;
}

/** choix null : temps écoulé (compté comme une mauvaise réponse). */
function resoudreCoupDuel(p: PartieDuel, choix: string | null, maintenant: number, alea: Alea): EffetDuel[] {
  const duel = p.duel as EtatDuel;
  const presentees = duel.presentees.slice();
  const r = choix === null ? repondreTempsEcoule(duel, alea) : repondre(duel, choix);
  p.coup = {
    type: "coup", poseur: r.proprietaire, carte: r.carte, presentees: presentees,
    choix: choix === null ? "" : choix, juste: r.juste, tempsEcoule: choix === null,
  };
  p.etape = "resultat";
  p.echeance = maintenant + RESULTAT_S * 1000;
  p.continuer = [false, false];
  p.version++;
  if (duel.phase === "finie") return terminerDuel(p, duel.gagnant, "cartes", maintenant);
  return [];
}

/** Message d'un joueur (indice i). */
function messageDuel(p: PartieDuel, i: number, op: number, data: any, maintenant: number, alea: Alea): EffetDuel[] {
  if (i < 0) return [];
  if (op === OP_ABANDONNER) {
    if (!enJeu(p)) return [];
    p.pauseReste = -1;
    return terminerDuel(p, 1 - i, "abandon", maintenant);
  }
  if (op === OP_REVANCHE) {
    if (p.etape !== "finie" || p.fin === null || p.fin.raison === "deconnexion" || absents(p).length > 0) return [];
    p.revanche[i] = data.accepte !== false;
    p.version++;
    if (data.accepte === false) {
      p.echeance = maintenant;  // l'autre est prévenu, la partie se ferme
      return [];
    }
    return p.revanche[0] && p.revanche[1] ? [{ type: "revanche" }] : [];
  }
  // Partie en pause : on attend le joueur déconnecté.
  if (enJeu(p) && absents(p).length > 0) return [];
  const duel = p.duel;
  if (duel === null) return [];
  const aTemps = p.echeance === 0 || maintenant <= p.echeance + MARGE_DIRECT_MS;
  if (op === OP_DEPART && p.etape === "depart" && p.depart !== null && aTemps) {
    const choix = String(data.choix || "");
    if (p.depart.propositions.indexOf(choix) < 0) return [];
    const juste = choix === p.depart.reponse;
    const commence = juste ? i : 1 - i;
    p.coup = { type: "depart", premier: i, choix: choix, juste: juste, bonne: p.depart.reponse, commence: commence };
    commencerDuel(duel, commence);
    p.depart = null;
    p.etape = "annonce";
    p.echeance = maintenant + ANNONCE_S * 1000;
    p.version++;
    return [];
  }
  if (op === OP_JOUER && p.etape === "choisir" && duel.poseur === i && aTemps) {
    const index = Number(data.index);
    const valide = index >= 0 && index < duel.mains[i].length && Math.floor(index) === index;
    poserCarteDuel(p, valide ? index : -1, !valide, maintenant, alea);
    return [];
  }
  if (op === OP_REPONDRE && p.etape === "repondre" && duel.poseur === 1 - i && aTemps) {
    const choix = String(data.choix || "");
    if (duel.presentees.indexOf(choix) < 0) return [];
    return resoudreCoupDuel(p, choix, maintenant, alea);
  }
  if (op === OP_CONTINUER && p.etape === "resultat") {
    p.continuer[i] = true;
    if ((p.continuer[0] || !p.joueurs[0].present) && (p.continuer[1] || !p.joueurs[1].present)) suivantDuel(p, maintenant);
    return [];
  }
  return [];
}

/** Un joueur quitte la partie (fermeture de l'application, perte du réseau). */
function departJoueurDuel(p: PartieDuel, userId: string, maintenant: number): EffetDuel[] {
  const i = indexJoueur(p, userId);
  if (i < 0 || p.etape === "annulee") return [];
  p.joueurs[i].present = false;
  p.joueurs[i].absentDepuis = maintenant;
  p.version++;
  if (p.etape === "attente") return annulerDuel(p, p.mode === "ami" ? "createur_parti" : "adversaire_absent");
  if (enJeu(p)) {
    if (p.pauseReste < 0) p.pauseReste = p.echeance > 0 ? Math.max(0, p.echeance - maintenant) : 0;
    return [];
  }
  // Partie finie : plus de revanche possible ; on ferme quand il n'y a plus personne.
  return absents(p).length === p.joueurs.length ? [{ type: "terminer" }] : [];
}

/** Appelé à chaque tic : délais de jeu, d'arrivée, de reconnexion et de revanche. */
function ticDuel(p: PartieDuel, maintenant: number, alea: Alea): EffetDuel[] {
  if (p.etape === "annulee") return [{ type: "terminer" }];
  if (p.etape === "attente") {
    const limite = p.mode === "ami" ? ATTENTE_AMI_S : ARRIVEE_S;
    return maintenant - p.creee > limite * 1000 ? annulerDuel(p, p.mode === "ami" ? "personne" : "adversaire_absent") : [];
  }
  if (enJeu(p)) {
    const a = absents(p);
    for (let k = 0; k < a.length; k++) {
      if (maintenant - p.joueurs[a[k]].absentDepuis > RECONNEXION_S * 1000) {
        if (a.length === 2) return annulerDuel(p, "deux_deconnectes");
        p.pauseReste = -1;
        return terminerDuel(p, 1 - a[k], "deconnexion", maintenant);
      }
    }
    if (a.length > 0) return [];
  }
  if (p.echeance === 0 || maintenant <= p.echeance + MARGE_DIRECT_MS) return [];
  switch (p.etape) {
    case "depart":
      // Personne n'a répondu : nouvelle question.
      poserQuestionDepartDuel(p, maintenant, alea);
      p.coup = { type: "nouvelle_question" };
      return [];
    case "annonce":
      p.etape = "choisir";
      p.echeance = maintenant + DUEL_CHOISIR_S * 1000;
      p.version++;
      return [];
    case "choisir":
      poserCarteDuel(p, -1, true, maintenant, alea);
      return [];
    case "repondre":
      return resoudreCoupDuel(p, null, maintenant, alea);
    case "resultat":
      suivantDuel(p, maintenant);
      return [];
    case "finie":
      p.echeance = 0;
      return [{ type: "terminer" }];
  }
  return [];
}

/** Revanche acceptée par les deux : nouvelle donne, même difficulté, même mise. */
function preparerRevanche(p: PartieDuel): void {
  p.fin = null;
  p.coup = null;
  p.duel = null;
  p.revanche = [false, false];
  p.version++;
}

// ---------------------------------------------------------------- Vue d'un joueur

function vueCoupDuel(p: PartieDuel, i: number): any {
  const c = p.coup;
  if (!c) return null;
  if (c.type === "coup") {
    const mienne = c.poseur === i;
    // La réponse d'une carte ratée reste secrète pour celui qui devait la trouver (PRD §2.5).
    return {
      type: "coup", mienne: mienne, carte: mienne || c.juste ? carteComplete(c.carte) : carteADeviner(c.carte, c.presentees),
      presentees: c.presentees, choix: c.choix, juste: c.juste, tempsEcoule: c.tempsEcoule,
    };
  }
  if (c.type === "depart") {
    return { type: "depart", parMoi: c.premier === i, choix: c.choix, juste: c.juste, bonne: c.bonne, jeCommence: c.commence === i };
  }
  if (c.type === "pose") return { type: "pose", parMoi: c.poseur === i, auHasard: c.auHasard };
  return { type: c.type };
}

function vueDuel(p: PartieDuel, i: number, maintenant: number): any {
  const j = 1 - i;
  const duel = p.duel;
  const autre = p.joueurs[j];
  const enPause = enJeu(p) && absents(p).length > 0;
  const restantMs = enPause ? p.pauseReste : (p.echeance > 0 ? p.echeance - maintenant : 0);
  let carte: any = null;
  if (p.etape === "repondre" && duel !== null && duel.jouee !== null) {
    if (duel.poseur === i) {
      carte = carteComplete(duel.jouee.id);
      carte.propositions = duel.presentees.slice();
    } else {
      carte = carteADeviner(duel.jouee.id, duel.presentees);
    }
  }
  let fin: any = null;
  if (p.fin !== null) {
    const gagne = p.fin.gagnant === i;
    fin = { gagne: gagne, raison: p.fin.raison, gain: gagne ? p.mise : -p.mise, xp: p.fin.xp[i] };
    const compte = p.fin.comptes[i];
    if (compte) {
      fin.talents = compte.talents;
      fin.xpTotal = compte.xpTotal;
      fin.niveauAvant = compte.niveauAvant;
      fin.niveau = compte.niveau;
    }
  }
  let reconnexion = 0;
  if (enPause) {
    absents(p).forEach(function (a) {
      reconnexion = Math.max(reconnexion, RECONNEXION_S * 1000 - (maintenant - p.joueurs[a].absentDepuis));
    });
  }
  return {
    etape: p.etape,
    mode: p.mode,
    code: p.etape === "attente" ? p.code : "",
    difficulte: p.difficulte,
    mise: p.mise,
    adversaire: autre ? { pseudo: autre.pseudo, niveau: autre.niveau, present: autre.present } : null,
    poseur: duel !== null && duel.poseur >= 0 ? (duel.poseur === i ? "moi" : "adversaire") : "",
    main: duel !== null ? duel.mains[i].map(function (c) { return { carte: carteComplete(c.id), fausses: c.montrees.slice(), reserve: c.reserve.length }; }) : [],
    mainAdverse: duel !== null ? duel.mains[j].length : 0,
    carte: carte,
    depart: p.etape === "depart" && p.depart !== null ? { question: questionDepart(p.depart.id), propositions: p.depart.propositions.slice() } : null,
    coup: vueCoupDuel(p, i),
    continuer: p.etape === "resultat" ? { moi: p.continuer[i], adversaire: p.continuer[j] } : null,
    // Cartes détruites : toutes trouvées, donc révélées aux deux joueurs (moi, puis l'adversaire).
    detruites: duel !== null ? [duel.detruites[i].map(carteComplete), duel.detruites[j].map(carteComplete)] : [[], []],
    temps: Math.max(0, Math.round(restantMs / 1000)),
    pause: enPause ? { adversaireAbsent: !!autre && !autre.present, reconnexion: Math.max(0, Math.round(reconnexion / 1000)) } : null,
    fin: fin,
    revanche: p.etape === "finie" ? {
      moi: p.revanche[i], adversaire: p.revanche[j],
      possible: p.fin !== null && p.fin.raison !== "deconnexion" && absents(p).length === 0 && p.echeance > maintenant,
    } : null,
    annulation: p.etape === "annulee" ? p.raisonAnnulation : "",
  };
}

// ---------------------------------------------------------------- Nakama

function labelDuel(p: PartieDuel): string {
  return JSON.stringify({ mode: p.mode, code: p.code, difficulte: p.difficulte, pseudo: p.pseudoCreateur, ouvert: p.etape === "attente" ? "oui" : "non" });
}

function envoyerVues(dispatcher: nkruntime.MatchDispatcher, p: PartieDuel, maintenant: number): void {
  p.joueurs.forEach(function (j, i) {
    const presence = p.presences[j.userId];
    if (j.present && presence) dispatcher.broadcastMessage(OP_VUE, JSON.stringify(vueDuel(p, i, maintenant)), [presence], null, true);
  });
}

/** Prélève les deux mises puis distribue. Si un joueur n'a plus assez de talents, la partie est annulée. */
function lancerDuel(nk: nkruntime.Nakama, logger: nkruntime.Logger, p: PartieDuel, maintenant: number): EffetDuel[] {
  const lues = p.joueurs.map(function (j) { return lireStockage(nk, j.userId, COLLECTION_PARTIES, CLE_RECENTES); });
  try {
    nk.walletsUpdate(p.joueurs.map(function (j) {
      return { userId: j.userId, changeset: { talents: -p.mise }, metadata: { raison: "mise_duel", mode: p.mode, difficulte: p.difficulte } };
    }), true);
  } catch (e) {
    logger.warn("Duel : mise impossible : %s", String(e));
    return annulerDuel(p, "talents");
  }
  demarrerDuel(p, cartesRecentes(lues.map(function (l) { return l.valeur; })), maintenant, Math.random);
  p.joueurs.forEach(function (j, i) {
    try {
      nk.storageWrite([ecritureRecentes(j.userId, lues[i], p.duel as EtatDuel)]);
    } catch (e) {
      logger.warn("Duel : cartes récentes non enregistrées pour %s : %s", j.userId, String(e));
    }
  });
  return [];
}

/** Gain du vainqueur (les deux mises), XP des deux joueurs, classement général. */
function reglerDuel(nk: nkruntime.Nakama, logger: nkruntime.Logger, p: PartieDuel): void {
  const fin = p.fin as FinDuel;
  const avant = p.joueurs.map(function (j) { return xpDe(nk, j.userId); });
  const maj: nkruntime.WalletUpdate[] = [];
  p.joueurs.forEach(function (j, i) {
    const changeset: { [cle: string]: number } = { xp: fin.xp[i] };
    if (i === fin.gagnant && p.misesPrelevees) changeset["talents"] = p.mise * 2;
    if (changeset["xp"] > 0 || changeset["talents"]) {
      maj.push({ userId: j.userId, changeset: changeset, metadata: { raison: i === fin.gagnant ? "gain_duel" : "xp_duel", mode: p.mode, difficulte: p.difficulte } });
    }
  });
  try {
    if (maj.length > 0) nk.walletsUpdate(maj, true);
    p.misesPrelevees = false;
  } catch (e) {
    logger.error("Duel : règlement refusé : %s", String(e));
  }
  if (p.salon) reglerScoreSalon(nk, logger, p.salon, p.joueurs.map(function (j) { return j.userId; }), fin.gagnant, Date.now());
  p.joueurs.forEach(function (j, i) {
    const xpTotal = xpDe(nk, j.userId);
    fin.comptes[i] = { talents: talentsDe(nk, j.userId), xpTotal: xpTotal, niveauAvant: niveauDepuisXp(avant[i]).niveau, niveau: niveauDepuisXp(xpTotal).niveau };
    if (fin.xp[i] > 0) inscrireClassement(nk, logger, j.userId, xpTotal);
  });
  p.version++;
}

function rembourserDuel(nk: nkruntime.Nakama, logger: nkruntime.Logger, p: PartieDuel): void {
  try {
    nk.walletsUpdate(p.joueurs.map(function (j) {
      return { userId: j.userId, changeset: { talents: p.mise }, metadata: { raison: "remboursement_duel", mode: p.mode, difficulte: p.difficulte } };
    }), true);
  } catch (e) {
    logger.error("Duel : remboursement refusé : %s", String(e));
  }
}

/** Applique les effets ; renvoie vrai s'il faut fermer la partie. */
function appliquerEffets(nk: nkruntime.Nakama, logger: nkruntime.Logger, dispatcher: nkruntime.MatchDispatcher, p: PartieDuel, effets: EffetDuel[], maintenant: number): boolean {
  let terminer = false;
  for (let k = 0; k < effets.length; k++) {
    const e = effets[k];
    if (e.type === "demarrer" || e.type === "revanche") {
      if (e.type === "revanche") preparerRevanche(p);
      const suite = lancerDuel(nk, logger, p, maintenant);
      if (appliquerEffets(nk, logger, dispatcher, p, suite, maintenant)) terminer = true;
      dispatcher.matchLabelUpdate(labelDuel(p));
    } else if (e.type === "regler") {
      reglerDuel(nk, logger, p);
    } else if (e.type === "rembourser") {
      rembourserDuel(nk, logger, p);
    } else if (e.type === "terminer") {
      terminer = true;
    }
  }
  return terminer;
}

const duelInit: nkruntime.MatchInitFunction<PartieDuel> = function (ctx, logger, nk, params) {
  chargerReglages(nk, logger);
  const attendus = params.attendus ? String(params.attendus).split(",") : [];
  const p = nouvellePartieDuel(String(params.mode), String(params.difficulte), String(params.code || ""), String(params.createur || ""), attendus, Date.now());
  if (params.salon) {
    const salon = lireSalon(nk, String(params.salon)).salon;
    p.salon = String(params.salon);
    p.contenu = salon ? salon.contenu : null;
  }
  if (p.createur) {
    try { p.pseudoCreateur = nk.accountGetId(p.createur).user.username; } catch (e) { p.pseudoCreateur = ""; }
  }
  return { state: p, tickRate: TICS_PAR_SECONDE, label: labelDuel(p) };
};

const duelEssaiArrivee: nkruntime.MatchJoinAttemptFunction<PartieDuel> = function (ctx, logger, nk, dispatcher, tick, state, presence, metadata) {
  chargerReglages(nk, logger);
  let raison = accepterArrivee(state, presence.userId);
  if (raison === "" && indexJoueur(state, presence.userId) < 0 && talentsDe(nk, presence.userId) < state.mise) {
    raison = "Pas assez de talents pour cette mise.";
  }
  return { state: state, accept: raison === "", rejectMessage: raison };
};

const duelArrivee: nkruntime.MatchJoinFunction<PartieDuel> = function (ctx, logger, nk, dispatcher, tick, state, presences) {
  chargerReglages(nk, logger);
  const maintenant = Date.now();
  let terminer = false;
  presences.forEach(function (presence) {
    state.presences[presence.userId] = presence;
    const compte = nk.accountGetId(presence.userId);
    const xp = (compte.wallet && compte.wallet["xp"]) || 0;
    const effets = arriveeDuel(state, presence.userId, compte.user.username, niveauDepuisXp(xp).niveau, maintenant);
    if (appliquerEffets(nk, logger, dispatcher, state, effets, maintenant)) terminer = true;
  });
  envoyerVues(dispatcher, state, maintenant);
  return terminer ? null : { state: state };
};

const duelDepartJoueur: nkruntime.MatchLeaveFunction<PartieDuel> = function (ctx, logger, nk, dispatcher, tick, state, presences) {
  chargerReglages(nk, logger);
  const maintenant = Date.now();
  let terminer = false;
  presences.forEach(function (presence) {
    delete state.presences[presence.userId];
    if (appliquerEffets(nk, logger, dispatcher, state, departJoueurDuel(state, presence.userId, maintenant), maintenant)) terminer = true;
  });
  envoyerVues(dispatcher, state, maintenant);
  return terminer ? null : { state: state };
};

const duelBoucle: nkruntime.MatchLoopFunction<PartieDuel> = function (ctx, logger, nk, dispatcher, tick, state, messages) {
  chargerReglages(nk, logger);
  const maintenant = Date.now();
  const version = state.version;
  let terminer = false;
  messages.forEach(function (m) {
    let data: any = {};
    try {
      const texte = nk.binaryToString(m.data);
      data = texte ? JSON.parse(texte) : {};
    } catch (e) {
      data = {};
    }
    const effets = messageDuel(state, indexJoueur(state, m.sender.userId), m.opCode, data || {}, maintenant, Math.random);
    if (appliquerEffets(nk, logger, dispatcher, state, effets, maintenant)) terminer = true;
  });
  if (appliquerEffets(nk, logger, dispatcher, state, ticDuel(state, maintenant, Math.random), maintenant)) terminer = true;
  // Vues renvoyées à chaque changement, et une fois par seconde pendant une pause (compte à rebours).
  if (state.version !== version || terminer || (enJeu(state) && absents(state).length > 0 && tick % TICS_PAR_SECONDE === 0)) {
    envoyerVues(dispatcher, state, maintenant);
  }
  return terminer ? null : { state: state };
};

const duelFin: nkruntime.MatchTerminateFunction<PartieDuel> = function (ctx, logger, nk, dispatcher, tick, state, graceSeconds) {
  // Arrêt du serveur en pleine partie : chacun récupère sa mise.
  if (state.misesPrelevees) rembourserDuel(nk, logger, state);
  state.misesPrelevees = false;
  return { state: state };
};

const duelSignal: nkruntime.MatchSignalFunction<PartieDuel> = function (ctx, logger, nk, dispatcher, tick, state, data) {
  return { state: state, data: "" };
};

/** Duel rapide : le matchmaker a trouvé deux joueurs de la même difficulté. */
const apresAppariement: nkruntime.MatchmakerMatchedFunction = function (ctx, logger, nk, matches) {
  chargerReglages(nk, logger);
  // Le matchmaker ne vérifie la requête que d'un côté : on exige la même propriété chez les deux,
  // et on contrôle ici l'appartenance au salon (un client peut envoyer n'importe quoi).
  const meme = function (cle: string) { return matches.every(function (m) { return m.properties[cle] === matches[0].properties[cle]; }); };
  const marque = matches[0].properties["salon"];
  if (marque) {
    if (!meme("salon")) return;
    const salon = salonParMarque(nk, marque);
    if (!salon || !matches.every(function (m) { return membreIndex(salon, m.presence.userId) >= 0; })) {
      logger.warn("Duel de salon refusé : %s", marque);
      return;
    }
    return nk.matchCreate(MODULE_DUEL, {
      mode: "salon", difficulte: salon.difficulte, salon: salon.id,
      attendus: matches.map(function (m) { return m.presence.userId; }).join(","),
    });
  }
  if (!meme("difficulte")) return;
  const difficulte = matches[0].properties["difficulte"];
  if (DIFFICULTES.indexOf(difficulte) < 0) {
    logger.warn("Duel rapide : difficulté inconnue %s", String(difficulte));
    return;
  }
  const ids = matches.map(function (m) { return m.presence.userId; });
  return nk.matchCreate(MODULE_DUEL, { mode: "rapide", difficulte: difficulte, attendus: ids.join(",") });
};

function partiesParCode(nk: nkruntime.Nakama, code: string): nkruntime.Match[] {
  return nk.matchList(1, true, null, 0, 1, "+label.code:" + code + " +label.ouvert:oui") || [];
}

const rpcDuelAmi: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  chargerReglages(nk, logger);
  if (!ctx.userId) throw refus("Connexion requise.", nkruntime.Codes.UNAUTHENTICATED);
  const demande = payload ? JSON.parse(payload) : {};
  if (demande.action === "creer") {
    const difficulte = String(demande.difficulte);
    if (DIFFICULTES.indexOf(difficulte) < 0) throw refus("Difficulté inconnue.", nkruntime.Codes.INVALID_ARGUMENT);
    const somme = mise("duel", difficulte);
    if (talentsDe(nk, ctx.userId) < somme) throw refus("Pas assez de talents pour cette difficulté.");
    let code = nouveauCode(Math.random);
    for (let essai = 0; essai < 10 && partiesParCode(nk, code).length > 0; essai++) code = nouveauCode(Math.random);
    const matchId = nk.matchCreate(MODULE_DUEL, { mode: "ami", difficulte: difficulte, code: code, createur: ctx.userId });
    return JSON.stringify({ matchId: matchId, code: code, difficulte: difficulte, mise: somme });
  }
  if (demande.action === "voir") {
    const code = String(demande.code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
    if (code.length !== LONGUEUR_CODE) throw refus("Le code a " + LONGUEUR_CODE + " caractères.", nkruntime.Codes.INVALID_ARGUMENT);
    const trouvees = partiesParCode(nk, code);
    if (trouvees.length === 0) throw refus("Aucune partie n'attend avec ce code.", nkruntime.Codes.NOT_FOUND);
    const label = JSON.parse(trouvees[0].label);
    return JSON.stringify({ matchId: trouvees[0].matchId, difficulte: label.difficulte, mise: mise("duel", label.difficulte), createur: label.pseudo });
  }
  throw refus("Action inconnue : " + String(demande.action), nkruntime.Codes.INVALID_ARGUMENT);
};
