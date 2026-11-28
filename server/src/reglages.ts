// Réglages du jeu modifiables depuis le back-office (backoffice/index.html), sans redéployer.
//
// Chaque réglage a une valeur par défaut (celle du code), des bornes et un libellé. Seules les valeurs
// changées sont stockées : collection « config », clé « reglages », propriétaire système, illisible par
// les joueurs. L'historique des changements est dans la clé « historique ». Chaque point d'entrée du
// module (RPC, hook, partie) appelle chargerReglages(nk) : relecture au plus toutes les 30 s.
//
// RPC « reglages » (joueurs) : toutes les valeurs en vigueur, pour l'affichage (mises, coûts, délais).
// RPC « reglages_admin » (clé HTTP du serveur seulement, via le back-office) :
//   lire                                   → { groupes, historique }
//   enregistrer { valeurs: { cle: n } }    → nouvelles valeurs, refusées hors bornes
//   reinitialiser { cles: [..] }           → retour aux valeurs par défaut

const COLLECTION_CONFIG = "config";
const CLE_REGLAGES = "reglages";
const CLE_HISTORIQUE = "historique";
const RELECTURE_MS = 30000;
const HISTORIQUE_MAX = 200;

interface Reglage { cle: string; groupe: string; libelle: string; unite: string; defaut: number; min: number; max: number; }

const REGLAGES: Reglage[] = [
  { cle: "capital_depart", groupe: "Économie", libelle: "Capital de départ", unite: "talents", defaut: 100, min: 0, max: 10000 },
  { cle: "pain_quotidien", groupe: "Économie", libelle: "Pain quotidien", unite: "talents", defaut: 10, min: 0, max: 1000 },
  { cle: "mise_arcade_lait", groupe: "Économie", libelle: "Mise en arcade · Lait", unite: "talents", defaut: 2, min: 1, max: 1000 },
  { cle: "mise_arcade_manne", groupe: "Économie", libelle: "Mise en arcade · Manne", unite: "talents", defaut: 5, min: 1, max: 1000 },
  { cle: "mise_arcade_solide", groupe: "Économie", libelle: "Mise en arcade · Nourriture solide", unite: "talents", defaut: 10, min: 1, max: 1000 },
  { cle: "mise_duel_lait", groupe: "Économie", libelle: "Mise en duel · Lait", unite: "talents", defaut: 5, min: 1, max: 10000 },
  { cle: "mise_duel_manne", groupe: "Économie", libelle: "Mise en duel · Manne", unite: "talents", defaut: 20, min: 1, max: 10000 },
  { cle: "mise_duel_solide", groupe: "Économie", libelle: "Mise en duel · Nourriture solide", unite: "talents", defaut: 50, min: 1, max: 10000 },
  { cle: "salon_cout", groupe: "Économie", libelle: "Coût de création d'un salon", unite: "talents", defaut: 30, min: 0, max: 10000 },

  { cle: "arcade_depart_s", groupe: "Délais", libelle: "Arcade · question de départ", unite: "s", defaut: 20, min: 5, max: 180 },
  { cle: "arcade_choisir_s", groupe: "Délais", libelle: "Arcade · choisir une carte", unite: "s", defaut: 20, min: 5, max: 180 },
  { cle: "arcade_repondre_s", groupe: "Délais", libelle: "Arcade · répondre", unite: "s", defaut: 30, min: 5, max: 180 },
  { cle: "duel_depart_s", groupe: "Délais", libelle: "Duel · question de départ", unite: "s", defaut: 30, min: 5, max: 180 },
  { cle: "duel_choisir_s", groupe: "Délais", libelle: "Duel · choisir une carte", unite: "s", defaut: 30, min: 5, max: 180 },
  { cle: "duel_repondre_s", groupe: "Délais", libelle: "Duel · répondre", unite: "s", defaut: 45, min: 5, max: 180 },
  { cle: "duel_resultat_s", groupe: "Délais", libelle: "Duel · écran de résultat d'un coup", unite: "s", defaut: 10, min: 3, max: 60 },
  { cle: "duel_reconnexion_s", groupe: "Délais", libelle: "Duel · délai pour revenir après une déconnexion", unite: "s", defaut: 30, min: 10, max: 300 },
  { cle: "duel_revanche_s", groupe: "Délais", libelle: "Duel · délai pour accepter la revanche", unite: "s", defaut: 15, min: 5, max: 120 },

  { cle: "xp_victoire", groupe: "Progression", libelle: "XP d'une victoire", unite: "XP", defaut: 30, min: 0, max: 1000 },
  { cle: "xp_defaite", groupe: "Progression", libelle: "XP d'une défaite", unite: "XP", defaut: 10, min: 0, max: 1000 },

  { cle: "ia_chance_lait", groupe: "Le Scribe", libelle: "Réussite avec 4 propositions · Lait", unite: "%", defaut: 65, min: 0, max: 100 },
  { cle: "ia_chance_manne", groupe: "Le Scribe", libelle: "Réussite avec 4 propositions · Manne", unite: "%", defaut: 55, min: 0, max: 100 },
  { cle: "ia_chance_solide", groupe: "Le Scribe", libelle: "Réussite avec 4 propositions · Nourriture solide", unite: "%", defaut: 45, min: 0, max: 100 },
  { cle: "ia_depart_chance", groupe: "Le Scribe", libelle: "Réussite à la question de départ", unite: "%", defaut: 70, min: 0, max: 100 },

  { cle: "aventure_questions", groupe: "Aventure", libelle: "Questions par partie", unite: "questions", defaut: 10, min: 3, max: 30 },
  { cle: "aventure_delai_s", groupe: "Aventure", libelle: "Délai pour répondre", unite: "s", defaut: 30, min: 5, max: 180 },
  { cle: "aventure_lait_1", groupe: "Aventure", libelle: "Lait · bonnes réponses pour ★", unite: "", defaut: 7, min: 1, max: 30 },
  { cle: "aventure_lait_2", groupe: "Aventure", libelle: "Lait · bonnes réponses pour ★★", unite: "", defaut: 9, min: 1, max: 30 },
  { cle: "aventure_lait_3", groupe: "Aventure", libelle: "Lait · bonnes réponses pour ★★★", unite: "", defaut: 10, min: 1, max: 30 },
  { cle: "aventure_manne_1", groupe: "Aventure", libelle: "Manne · bonnes réponses pour ★", unite: "", defaut: 6, min: 1, max: 30 },
  { cle: "aventure_manne_2", groupe: "Aventure", libelle: "Manne · bonnes réponses pour ★★", unite: "", defaut: 8, min: 1, max: 30 },
  { cle: "aventure_manne_3", groupe: "Aventure", libelle: "Manne · bonnes réponses pour ★★★", unite: "", defaut: 10, min: 1, max: 30 },
  { cle: "aventure_solide_1", groupe: "Aventure", libelle: "Solide · bonnes réponses pour ★", unite: "", defaut: 5, min: 1, max: 30 },
  { cle: "aventure_solide_2", groupe: "Aventure", libelle: "Solide · bonnes réponses pour ★★", unite: "", defaut: 8, min: 1, max: 30 },
  { cle: "aventure_solide_3", groupe: "Aventure", libelle: "Solide · bonnes réponses pour ★★★", unite: "", defaut: 10, min: 1, max: 30 },
  { cle: "aventure_xp_bonne", groupe: "Aventure", libelle: "XP par bonne réponse", unite: "XP", defaut: 3, min: 0, max: 100 },
  { cle: "aventure_talents_etoile", groupe: "Aventure", libelle: "Talents par étoile nouvelle", unite: "talents", defaut: 2, min: 0, max: 100 },

  { cle: "cartes_brouillons", groupe: "Cartes", libelle: "Jouer aussi les brouillons (1 : oui, 0 : validées seules)", unite: "", defaut: 1, min: 0, max: 1 },

  { cle: "salon_membres_max", groupe: "Salons", libelle: "Membres au maximum", unite: "joueurs", defaut: 50, min: 2, max: 500 },
  { cle: "salon_questions_min", groupe: "Salons", libelle: "Questions validées au minimum pour un salon", unite: "questions", defaut: 10, min: 1, max: 1000 },
  { cle: "salon_score_victoire", groupe: "Salons", libelle: "Score de salon d'une victoire", unite: "points", defaut: 10, min: 0, max: 1000 },
  { cle: "salon_score_defaite", groupe: "Salons", libelle: "Score de salon retiré par une défaite", unite: "points", defaut: 5, min: 0, max: 1000 },
  { cle: "salon_inactif_jours", groupe: "Salons", libelle: "Suppression d'un salon sans partie depuis", unite: "jours", defaut: 7, min: 1, max: 365 },
];

let reglagesLusA = 0;
let reglagesValeurs: { [cle: string]: number } = {};

function reglageParCle(cle: string): Reglage | null {
  for (let i = 0; i < REGLAGES.length; i++) if (REGLAGES[i].cle === cle) return REGLAGES[i];
  return null;
}

/** "" si la valeur est acceptable pour ce réglage, sinon la raison du refus. */
function verifierReglage(cle: string, valeur: any): string {
  const r = reglageParCle(cle);
  if (r === null) return "Réglage inconnu : " + cle + ".";
  const n = Number(valeur);
  if (typeof valeur !== "number" || !isFinite(n) || Math.floor(n) !== n) return r.libelle + " : nombre entier attendu.";
  if (n < r.min || n > r.max) return r.libelle + " : entre " + r.min + " et " + r.max + " " + r.unite + ".";
  return "";
}

/** Valeurs en vigueur : les défauts, remplacés par les valeurs stockées qui restent valides. */
function valeursEnVigueur(stockees: { [cle: string]: any }): { [cle: string]: number } {
  const v: { [cle: string]: number } = {};
  REGLAGES.forEach(function (r) {
    const s = stockees ? stockees[r.cle] : undefined;
    v[r.cle] = s !== undefined && verifierReglage(r.cle, s) === "" ? Number(s) : r.defaut;
  });
  return v;
}

/** Recopie les valeurs dans les constantes du module (lues par les règles et les parties). */
function appliquerReglages(v: { [cle: string]: number }): void {
  reglagesValeurs = v;
  CAPITAL_DEPART = v["capital_depart"];
  PAIN_QUOTIDIEN = v["pain_quotidien"];
  // Nakama fige les objets globaux après InitModule : on remplace l'objet entier, sans jamais le modifier.
  MISES_ARCADE = { lait: v["mise_arcade_lait"], manne: v["mise_arcade_manne"], solide: v["mise_arcade_solide"] };
  MISES_DUEL = { lait: v["mise_duel_lait"], manne: v["mise_duel_manne"], solide: v["mise_duel_solide"] };
  SALON_COUT = v["salon_cout"];
  BROUILLONS_JOUABLES = v["cartes_brouillons"];
  QUIZ_QUESTIONS = v["aventure_questions"];
  QUIZ_DELAI_S = v["aventure_delai_s"];
  QUIZ_XP_BONNE = v["aventure_xp_bonne"];
  QUIZ_TALENTS_ETOILE = v["aventure_talents_etoile"];
  QUIZ_SEUILS = {
    lait: [v["aventure_lait_1"], v["aventure_lait_2"], v["aventure_lait_3"]],
    manne: [v["aventure_manne_1"], v["aventure_manne_2"], v["aventure_manne_3"]],
    solide: [v["aventure_solide_1"], v["aventure_solide_2"], v["aventure_solide_3"]],
  };
  DELAI_DEPART_S = v["arcade_depart_s"];
  DELAI_CHOISIR_S = v["arcade_choisir_s"];
  DELAI_REPONDRE_S = v["arcade_repondre_s"];
  DUEL_DEPART_S = v["duel_depart_s"];
  DUEL_CHOISIR_S = v["duel_choisir_s"];
  DUEL_REPONDRE_S = v["duel_repondre_s"];
  RESULTAT_S = v["duel_resultat_s"];
  RECONNEXION_S = v["duel_reconnexion_s"];
  REVANCHE_S = v["duel_revanche_s"];
  XP_VICTOIRE = v["xp_victoire"];
  XP_DEFAITE = v["xp_defaite"];
  CHANCES_IA = { lait: v["ia_chance_lait"] / 100, manne: v["ia_chance_manne"] / 100, solide: v["ia_chance_solide"] / 100 };
  CHANCE_DEPART_IA = v["ia_depart_chance"] / 100;
  SALON_MEMBRES_MAX = v["salon_membres_max"];
  SALON_QUESTIONS_MIN = v["salon_questions_min"];
  SALON_VICTOIRE = v["salon_score_victoire"];
  SALON_DEFAITE = v["salon_score_defaite"];
  SALON_INACTIF_MS = v["salon_inactif_jours"] * 24 * 60 * 60 * 1000;
}

function lireReglagesStockes(nk: nkruntime.Nakama): { valeurs: { [cle: string]: any }; version: string } {
  const lus = nk.storageRead([{ collection: COLLECTION_CONFIG, key: CLE_REGLAGES, userId: SYSTEME }]);
  if (lus.length === 0) return { valeurs: {}, version: "*" };
  const v = JSON.parse(JSON.stringify(lus[0].value));
  return { valeurs: v.valeurs || {}, version: lus[0].version };
}

/** À appeler à chaque point d'entrée : relit les réglages au plus toutes les 30 s. */
function chargerReglages(nk: nkruntime.Nakama, logger?: nkruntime.Logger): void {
  const maintenant = Date.now();
  if (maintenant - reglagesLusA < RELECTURE_MS) return;
  reglagesLusA = maintenant;
  try {
    appliquerReglages(valeursEnVigueur(lireReglagesStockes(nk).valeurs));
    chargerCartes(nk);
  } catch (e) {
    if (logger) logger.warn("Réglages : lecture impossible, valeurs précédentes gardées : %s", String(e));
  }
}

function lireHistorique(nk: nkruntime.Nakama): { entrees: any[]; version: string } {
  const lus = nk.storageRead([{ collection: COLLECTION_CONFIG, key: CLE_HISTORIQUE, userId: SYSTEME }]);
  if (lus.length === 0) return { entrees: [], version: "*" };
  return { entrees: JSON.parse(JSON.stringify(lus[0].value)).entrees || [], version: lus[0].version };
}

function vueAdmin(nk: nkruntime.Nakama): string {
  const stockees = lireReglagesStockes(nk).valeurs;
  const v = valeursEnVigueur(stockees);
  const groupes: any[] = [];
  REGLAGES.forEach(function (r) {
    let g = groupes.filter(function (x) { return x.nom === r.groupe; })[0];
    if (!g) { g = { nom: r.groupe, reglages: [] }; groupes.push(g); }
    g.reglages.push({ cle: r.cle, libelle: r.libelle, unite: r.unite, defaut: r.defaut, min: r.min, max: r.max, valeur: v[r.cle] });
  });
  return JSON.stringify({ groupes: groupes, historique: lireHistorique(nk).entrees.slice(0, 50) });
}

const rpcReglages: nkruntime.RpcFunction = function (ctx, logger, nk, _payload) {
  chargerReglages(nk, logger);
  return JSON.stringify(reglagesValeurs);
};

const rpcReglagesAdmin: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  // Réservé à la clé HTTP du serveur : un joueur connecté a toujours un userId.
  if (ctx.userId) throw refus("Réservé au back-office.", nkruntime.Codes.PERMISSION_DENIED);
  const d = payload ? JSON.parse(payload) : {};
  const action = String(d.action || "lire");
  const auteur = (ctx.queryParams && ctx.queryParams["auteur"] && ctx.queryParams["auteur"][0]) || "inconnu";
  if (action === "lire") return vueAdmin(nk);
  if (action !== "enregistrer" && action !== "reinitialiser") throw refus("Action inconnue : " + action, nkruntime.Codes.INVALID_ARGUMENT);

  const lu = lireReglagesStockes(nk);
  const avant = valeursEnVigueur(lu.valeurs);
  const nouvelles: { [cle: string]: any } = JSON.parse(JSON.stringify(lu.valeurs));
  if (action === "enregistrer") {
    const valeurs = d.valeurs || {};
    const erreurs: string[] = [];
    Object.keys(valeurs).forEach(function (cle) {
      const e = verifierReglage(cle, valeurs[cle]);
      if (e) erreurs.push(e);
    });
    if (erreurs.length > 0) throw refus(erreurs.join(" "), nkruntime.Codes.INVALID_ARGUMENT);
    Object.keys(valeurs).forEach(function (cle) {
      const r = reglageParCle(cle) as Reglage;
      if (valeurs[cle] === r.defaut) delete nouvelles[cle];
      else nouvelles[cle] = valeurs[cle];
    });
  } else {
    const cles: string[] = Array.isArray(d.cles) ? d.cles.map(String) : REGLAGES.map(function (r) { return r.cle; });
    cles.forEach(function (cle) { delete nouvelles[cle]; });
  }
  const apres = valeursEnVigueur(nouvelles);
  const changements = REGLAGES.filter(function (r) { return avant[r.cle] !== apres[r.cle]; })
    .map(function (r) { return { cle: r.cle, libelle: r.libelle, avant: avant[r.cle], apres: apres[r.cle] }; });
  if (changements.length === 0) return vueAdmin(nk);
  if (apres["cartes_brouillons"] === 0 && avant["cartes_brouillons"] !== 0) {
    // Ne pas laisser le jeu sans cartes : il faut assez de validées avant d'écarter les brouillons.
    chargerReglages(nk, logger);
    const actuel = BROUILLONS_JOUABLES;
    BROUILLONS_JOUABLES = 0;
    const bloque = reserveInjouable(lireReserve(nk, "en_ligne").reserve);
    BROUILLONS_JOUABLES = actuel;
    if (bloque) throw refus("Validez d'abord plus de cartes en ligne (" + bloque + ").");
  }

  const h = lireHistorique(nk);
  const entrees = [{ quand: Date.now(), auteur: auteur, changements: changements }].concat(h.entrees).slice(0, HISTORIQUE_MAX);
  nk.storageWrite([
    { collection: COLLECTION_CONFIG, key: CLE_REGLAGES, userId: SYSTEME, value: { valeurs: nouvelles }, version: lu.version, permissionRead: 0, permissionWrite: 0 },
    { collection: COLLECTION_CONFIG, key: CLE_HISTORIQUE, userId: SYSTEME, value: { entrees: entrees }, version: h.version, permissionRead: 0, permissionWrite: 0 },
  ]);
  logger.info("Réglages modifiés par %s : %s", auteur, changements.map(function (c) { return c.cle + " " + c.avant + " → " + c.apres; }).join(", "));
  reglagesLusA = 0;
  chargerReglages(nk, logger);
  return vueAdmin(nk);
};
