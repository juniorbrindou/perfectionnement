// Gestion des cartes depuis le back-office : créer, modifier, retirer, importer et exporter en JSON,
// sans redéployer.
//
// Deux réserves sans carte commune : « en_ligne » (arcade, duels, salons) et « telephone » (partie à
// deux). Stockage : collection « cartes », clé = réserve, valeur { cartes, depart }, propriétaire
// système, illisible par les joueurs. Tant qu'une réserve n'a jamais été modifiée, ce sont les
// fichiers data/ embarqués à la compilation qui servent (SEMENCE). Ensuite le serveur fait foi : un
// changement des fichiers du dépôt s'importe depuis le back-office.
//
// Statuts : « brouillon », « valide », « retiree » (corbeille : plus jamais tirée, mais gardée pour
// les parties en cours qui la citent, et restaurable).
//
// RPC « cartes_admin » (clé HTTP seulement) { action, reserve, type: "cartes" | "depart", ... } :
//   lire                      → { cartes, depart, jouables, minimum }
//   enregistrer { fiches }    → crée ou remplace les fiches par id (tout ou rien)
//   statut { ids, statut }    → valider, repasser en brouillon, retirer
//   importer { cartes?, depart?, mode: "fusionner" | "remplacer", essai? }
// RPC « cartes_telephone » (joueurs) → { version, cartes, depart } : la réserve de la partie à deux.

interface FicheCarte {
  id: string; difficulty: string; testament: string; books: string[]; category: string; question: string;
  answer: string; wrongs: string[]; reference: string; explanation: string; story: string; status: string;
}
interface FicheDepart { id: string; question: string; answer: string; wrongs: string[]; reference: string; status: string; }
interface Reserve { cartes: FicheCarte[]; depart: FicheDepart[]; }

const COLLECTION_CARTES = "cartes";
const RESERVES = ["en_ligne", "telephone"];
const STATUTS = ["brouillon", "valide", "retiree"];
const CATEGORIES_CARTES = ["personnages", "miracles", "paraboles", "lieux_evenements"];
const LIVRES_AT = [
  "Genèse", "Exode", "Lévitique", "Nombres", "Deutéronome", "Josué", "Juges", "Ruth",
  "1 Samuel", "2 Samuel", "1 Rois", "2 Rois", "1 Chroniques", "2 Chroniques", "Esdras",
  "Néhémie", "Esther", "Job", "Psaumes", "Proverbes", "Ecclésiaste", "Cantique des cantiques",
  "Ésaïe", "Jérémie", "Lamentations", "Ézéchiel", "Daniel", "Osée", "Joël", "Amos", "Abdias",
  "Jonas", "Michée", "Nahum", "Habacuc", "Sophonie", "Aggée", "Zacharie", "Malachie",
];
const LIVRES_NT = [
  "Matthieu", "Marc", "Luc", "Jean", "Actes", "Romains", "1 Corinthiens", "2 Corinthiens",
  "Galates", "Éphésiens", "Philippiens", "Colossiens", "1 Thessaloniciens",
  "2 Thessaloniciens", "1 Timothée", "2 Timothée", "Tite", "Philémon", "Hébreux", "Jacques",
  "1 Pierre", "2 Pierre", "1 Jean", "2 Jean", "3 Jean", "Jude", "Apocalypse",
];
const FAUSSES_PAR_CARTE = 5;
const FAUSSES_PAR_DEPART = 4;
const MINIMUM_PAR_DIFFICULTE = 10;  // deux mains de cinq cartes

/** 1 : les brouillons sont tirés comme les cartes validées (réglage « cartes_brouillons »). */
let BROUILLONS_JOUABLES = 1;

// ---------------------------------------------------------------- Règles pures

function texte(v: any): string {
  return typeof v === "string" ? v.replace(/\s+/g, " ").trim() : "";
}

/** Fiche nettoyée (champs connus seulement, espaces réduits). */
function normaliserCarte(d: any): FicheCarte {
  return {
    id: texte(d.id), difficulty: texte(d.difficulty), testament: texte(d.testament),
    books: Array.isArray(d.books) ? d.books.map(texte).filter(function (x: string) { return x !== ""; }) : [],
    category: texte(d.category), question: texte(d.question), answer: texte(d.answer),
    wrongs: Array.isArray(d.wrongs) ? d.wrongs.map(texte).filter(function (x: string) { return x !== ""; }) : [],
    reference: texte(d.reference), explanation: texte(d.explanation), story: texte(d.story),
    status: texte(d.status) || "brouillon",
  };
}

function normaliserDepart(d: any): FicheDepart {
  return {
    id: texte(d.id), question: texte(d.question), answer: texte(d.answer),
    wrongs: Array.isArray(d.wrongs) ? d.wrongs.map(texte).filter(function (x: string) { return x !== ""; }) : [],
    reference: texte(d.reference), status: texte(d.status) || "brouillon",
  };
}

function propositionsEnDouble(reponse: string, fausses: string[]): string[] {
  const vues: { [k: string]: boolean } = {};
  vues[reponse.toLowerCase()] = true;
  const erreurs: string[] = [];
  fausses.forEach(function (f) {
    if (vues[f.toLowerCase()]) erreurs.push("proposition en double : " + f);
    vues[f.toLowerCase()] = true;
  });
  return erreurs;
}

/** Mêmes contrôles que CardData.problems() côté application. */
function problemesCarte(c: FicheCarte): string[] {
  const e: string[] = [];
  if (!/^[A-Za-z0-9_-]{2,40}$/.test(c.id)) e.push("identifiant manquant ou invalide (lettres, chiffres, - et _)");
  if (DIFFICULTES.indexOf(c.difficulty) < 0) e.push("difficulté inconnue");
  if (c.testament !== "AT" && c.testament !== "NT") e.push("testament : AT ou NT");
  if (c.books.length === 0) e.push("aucun livre");
  c.books.forEach(function (b) {
    if (LIVRES_AT.indexOf(b) < 0 && LIVRES_NT.indexOf(b) < 0) e.push("livre inconnu : " + b);
  });
  if (CATEGORIES_CARTES.indexOf(c.category) < 0) e.push("catégorie inconnue");
  if (!c.question) e.push("question manquante");
  if (!c.answer) e.push("bonne réponse manquante");
  if (!c.reference) e.push("référence manquante");
  if (!c.story) e.push("récit manquant");
  if (c.wrongs.length !== FAUSSES_PAR_CARTE) e.push(FAUSSES_PAR_CARTE + " fausses réponses attendues (" + c.wrongs.length + ")");
  if (STATUTS.indexOf(c.status) < 0) e.push("statut inconnu");
  return e.concat(propositionsEnDouble(c.answer, c.wrongs));
}

function problemesDepart(q: FicheDepart): string[] {
  const e: string[] = [];
  if (!/^[A-Za-z0-9_-]{2,40}$/.test(q.id)) e.push("identifiant manquant ou invalide (lettres, chiffres, - et _)");
  if (!q.question) e.push("question manquante");
  if (!q.answer) e.push("bonne réponse manquante");
  if (!q.reference) e.push("référence manquante");
  if (q.wrongs.length !== FAUSSES_PAR_DEPART) e.push(FAUSSES_PAR_DEPART + " fausses réponses attendues (" + q.wrongs.length + ")");
  if (STATUTS.indexOf(q.status) < 0) e.push("statut inconnu");
  return e.concat(propositionsEnDouble(q.answer, q.wrongs));
}

function estJouable(statut: string): boolean {
  return statut === "valide" || (statut === "brouillon" && BROUILLONS_JOUABLES === 1);
}

/** Cartes tirables par difficulté, et nombre de questions de départ tirables. */
function jouables(r: Reserve): { [cle: string]: number } {
  const n: { [cle: string]: number } = { lait: 0, manne: 0, solide: 0, depart: 0 };
  r.cartes.forEach(function (c) { if (estJouable(c.status)) n[c.difficulty]++; });
  r.depart.forEach(function (q) { if (estJouable(q.status)) n["depart"]++; });
  return n;
}

/** "" si la réserve permet encore de jouer, sinon la raison. */
function reserveInjouable(r: Reserve): string {
  const n = jouables(r);
  const manques: string[] = [];
  DIFFICULTES.forEach(function (d) {
    if (n[d] < MINIMUM_PAR_DIFFICULTE) manques.push(d + " : " + n[d] + " carte(s) jouable(s) sur " + MINIMUM_PAR_DIFFICULTE);
  });
  if (n["depart"] < 1) manques.push("aucune question de départ jouable");
  return manques.join(" ; ");
}

/** Remplace par id ou ajoute à la fin. */
function fusionner<T extends { id: string }>(actuelles: T[], nouvelles: T[]): T[] {
  const parId: { [id: string]: T } = {};
  nouvelles.forEach(function (n) { parId[n.id] = n; });
  const vus: { [id: string]: boolean } = {};
  const r = actuelles.map(function (a) { vus[a.id] = true; return parId[a.id] || a; });
  nouvelles.forEach(function (n) { if (!vus[n.id]) r.push(n); });
  return r;
}

/**
 * Applique des fiches à une réserve. Renvoie la nouvelle réserve et les erreurs (rien n'est écrit s'il
 * y en a) : fiche invalide, identifiant répété, ou carte déjà présente dans l'autre réserve.
 */
function appliquerFiches(actuelle: Reserve, autre: Reserve, cartes: any[], depart: any[], remplacer: boolean):
  { reserve: Reserve; erreurs: string[]; ajoutees: number; modifiees: number; retirees: number } {
  const erreurs: string[] = [];
  const lot: { [id: string]: boolean } = {};
  const ailleurs: { [cle: string]: string } = {};
  autre.cartes.forEach(function (c) { ailleurs["id:" + c.id] = c.id; ailleurs["q:" + c.question.toLowerCase()] = c.id; });
  autre.depart.forEach(function (q) { ailleurs["id:" + q.id] = q.id; ailleurs["q:" + q.question.toLowerCase()] = q.id; });
  const controler = function (f: { id: string; question: string }, problemes: string[]) {
    const nom = f.id || f.question.slice(0, 30) || "fiche sans identifiant";
    problemes.forEach(function (p) { erreurs.push(nom + " : " + p); });
    if (lot[f.id]) erreurs.push(nom + " : identifiant répété");
    lot[f.id] = true;
    const jumelle = ailleurs["id:" + f.id] || (f.question ? ailleurs["q:" + f.question.toLowerCase()] : "");
    if (jumelle) erreurs.push(nom + " : déjà dans l'autre réserve (" + jumelle + "), ce qui permettrait de tricher");
  };
  const nc = cartes.map(normaliserCarte);
  const nd = depart.map(normaliserDepart);
  nc.forEach(function (c) { controler(c, problemesCarte(c)); });
  nd.forEach(function (q) { controler(q, problemesDepart(q)); });

  const idsDepart: { [id: string]: boolean } = {};
  actuelle.depart.forEach(function (q) { idsDepart[q.id] = true; });
  const idsCartes: { [id: string]: boolean } = {};
  actuelle.cartes.forEach(function (c) { idsCartes[c.id] = true; });
  nc.forEach(function (c) { if (idsDepart[c.id]) erreurs.push(c.id + " : identifiant déjà pris par une question de départ"); });
  nd.forEach(function (q) { if (idsCartes[q.id]) erreurs.push(q.id + " : identifiant déjà pris par une carte"); });

  let ajoutees = 0, modifiees = 0, retirees = 0;
  const compter = function (anciennes: any[], nouvelles: any[]) {
    const parId: { [id: string]: any } = {};
    anciennes.forEach(function (a) { parId[a.id] = a; });
    nouvelles.forEach(function (n) {
      if (!parId[n.id]) ajoutees++;
      else if (JSON.stringify(parId[n.id]) !== JSON.stringify(n)) modifiees++;
    });
  };
  compter(actuelle.cartes, nc);
  compter(actuelle.depart, nd);

  // « Remplacer » : ce que le fichier ne contient plus part à la corbeille, sans être détruit.
  const corbeille = function <T extends { id: string; status: string }>(anciennes: T[], nouvelles: T[]): T[] {
    const gardees: { [id: string]: boolean } = {};
    nouvelles.forEach(function (n) { gardees[n.id] = true; });
    return anciennes.map(function (a) {
      if (gardees[a.id] || a.status === "retiree") return a;
      retirees++;
      const copie = JSON.parse(JSON.stringify(a));
      copie.status = "retiree";
      return copie;
    });
  };
  const baseCartes = remplacer && nc.length > 0 ? corbeille(actuelle.cartes, nc) : actuelle.cartes;
  const baseDepart = remplacer && nd.length > 0 ? corbeille(actuelle.depart, nd) : actuelle.depart;
  return {
    reserve: { cartes: fusionner(baseCartes, nc), depart: fusionner(baseDepart, nd) },
    erreurs: erreurs, ajoutees: ajoutees, modifiees: modifiees, retirees: retirees,
  };
}

/** Change le statut de fiches existantes (cartes ou questions de départ). */
function changerStatut(r: Reserve, ids: string[], statut: string): { reserve: Reserve; changees: number } {
  let changees = 0;
  const appliquer = function <T extends { id: string; status: string }>(liste: T[]): T[] {
    return liste.map(function (f) {
      if (ids.indexOf(f.id) < 0 || f.status === statut) return f;
      changees++;
      const copie = JSON.parse(JSON.stringify(f));
      copie.status = statut;
      return copie;
    });
  };
  return { reserve: { cartes: appliquer(r.cartes), depart: appliquer(r.depart) }, changees: changees };
}

/** Met en service la réserve en ligne : tirage (jouables) et recherche par id (toutes). */
function installerCartes(r: Reserve): void {
  // Nakama fige les objets globaux : on remplace les tableaux, sans les modifier.
  const tirables = r.cartes.filter(function (c) { return estJouable(c.status); });
  const depart = r.depart.filter(function (q) { return estJouable(q.status); });
  CARTES = tirables;
  QUESTIONS_DEPART = depart;
  CARTES_TOUTES = r.cartes;
  DEPART_TOUTES = r.depart;
}

// ---------------------------------------------------------------- Nakama

function lireReserve(nk: nkruntime.Nakama, nom: string): { reserve: Reserve; version: string } {
  const lus = nk.storageRead([{ collection: COLLECTION_CARTES, key: nom, userId: SYSTEME }]);
  if (lus.length === 0) return { reserve: JSON.parse(JSON.stringify(SEMENCE[nom])), version: "*" };
  const v = JSON.parse(JSON.stringify(lus[0].value));
  return { reserve: { cartes: v.cartes || [], depart: v.depart || [] }, version: lus[0].version };
}

function chargerCartes(nk: nkruntime.Nakama): void {
  installerCartes(lireReserve(nk, "en_ligne").reserve);
}

function vueCartes(nk: nkruntime.Nakama, nom: string): string {
  const r = lireReserve(nk, nom).reserve;
  return JSON.stringify({ reserve: nom, cartes: r.cartes, depart: r.depart, jouables: jouables(r), minimum: MINIMUM_PAR_DIFFICULTE,
    brouillons: BROUILLONS_JOUABLES === 1, livres: LIVRES_AT.concat(LIVRES_NT) });
}

const rpcCartesAdmin: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  if (ctx.userId) throw refus("Réservé au back-office.", nkruntime.Codes.PERMISSION_DENIED);
  chargerReglages(nk, logger);
  const d = payload ? JSON.parse(payload) : {};
  const action = String(d.action || "lire");
  const nom = String(d.reserve || "en_ligne");
  if (RESERVES.indexOf(nom) < 0) throw refus("Réserve inconnue.", nkruntime.Codes.INVALID_ARGUMENT);
  if (action === "lire") return vueCartes(nk, nom);

  const auteur = (ctx.queryParams && ctx.queryParams["auteur"] && ctx.queryParams["auteur"][0]) || "inconnu";
  const lue = lireReserve(nk, nom);
  const autre = lireReserve(nk, nom === "en_ligne" ? "telephone" : "en_ligne").reserve;
  let nouvelle: Reserve;
  let resume: any;
  if (action === "enregistrer" || action === "importer") {
    const cartes = Array.isArray(d.cartes) ? d.cartes : [];
    const depart = Array.isArray(d.depart) ? d.depart : [];
    if (cartes.length + depart.length === 0) throw refus("Aucune fiche à enregistrer.", nkruntime.Codes.INVALID_ARGUMENT);
    if (action === "enregistrer" && d.nouvelle) {
      const pris = lue.reserve.cartes.concat(lue.reserve.depart as any[]).map(function (f: any) { return f.id; });
      cartes.concat(depart).forEach(function (f: any) {
        if (pris.indexOf(texte(f.id)) >= 0) throw refus("L'identifiant " + texte(f.id) + " existe déjà.", nkruntime.Codes.ALREADY_EXISTS);
      });
    }
    const res = appliquerFiches(lue.reserve, autre, cartes, depart, action === "importer" && d.mode === "remplacer");
    if (res.erreurs.length > 0) {
      throw refus(res.erreurs.slice(0, 8).join(" | ") + (res.erreurs.length > 8 ? " | … et " + (res.erreurs.length - 8) + " autres" : ""), nkruntime.Codes.INVALID_ARGUMENT);
    }
    nouvelle = res.reserve;
    resume = { ajoutees: res.ajoutees, modifiees: res.modifiees, retirees: res.retirees };
  } else if (action === "statut") {
    const statut = String(d.statut);
    if (STATUTS.indexOf(statut) < 0) throw refus("Statut inconnu.", nkruntime.Codes.INVALID_ARGUMENT);
    const res = changerStatut(lue.reserve, Array.isArray(d.ids) ? d.ids.map(String) : [], statut);
    nouvelle = res.reserve;
    resume = { changees: res.changees, statut: statut };
  } else {
    throw refus("Action inconnue : " + action, nkruntime.Codes.INVALID_ARGUMENT);
  }

  const bloque = reserveInjouable(nouvelle);
  if (bloque && !reserveInjouable(lue.reserve)) throw refus("Refusé : le jeu ne pourrait plus distribuer (" + bloque + ").");
  if (d.essai) return JSON.stringify({ essai: true, resume: resume });

  const total = (resume.ajoutees || 0) + (resume.modifiees || 0) + (resume.retirees || 0) + (resume.changees || 0);
  if (total > 0) {
    nk.storageWrite([{ collection: COLLECTION_CARTES, key: nom, userId: SYSTEME, value: nouvelle as any, version: lue.version, permissionRead: 0, permissionWrite: 0 }]);
    logger.info("Cartes (%s) : %s par %s %s", nom, action, auteur, JSON.stringify(resume));
    if (nom === "en_ligne") installerCartes(nouvelle);
  }
  const vue = JSON.parse(vueCartes(nk, nom));
  vue.resume = resume;
  return JSON.stringify(vue);
};

/** Réserve de la partie à deux, pour que l'application la mette à jour sans nouvel APK. */
const rpcCartesTelephone: nkruntime.RpcFunction = function (ctx, logger, nk, _payload) {
  chargerReglages(nk, logger);
  const lue = lireReserve(nk, "telephone");
  return JSON.stringify({
    version: lue.version === "*" ? "" : lue.version,
    cartes: lue.reserve.cartes.filter(function (c) { return estJouable(c.status); }),
    depart: lue.reserve.depart.filter(function (q) { return estJouable(q.status); }),
  });
};
