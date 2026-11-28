// Salons (PRD §6, revu le 2026-11-27) : communautés permanentes. Tous les salons sont listés ;
// on en choisit un et on envoie une demande d'adhésion, que le Berger accepte ou refuse.
// Plus de salon public ou privé, plus de code.
//
// RPC « salon » { action, ... } :
//   options                                → seuils, coût, nombre de questions par critère
//   lister { recherche?, difficulte? }    → { salons, monSalon, maDemande }
//   voir { id }                           → fiche (et demandes reçues si l'on est le Berger)
//   creer { nom, devise, couleur, theme, difficulte, contenu }
//   demander { id }   annuler_demande   repondre { id, joueur, accepte }   quitter
//
// Stockage : chaque salon appartient à l'utilisateur système (collection « salons », clé = id) ;
// chaque joueur garde son lien (collection « joueur », clé « salon » : { salon, demande }).
// La logique est en fonctions pures sur l'état, testées sans Nakama.

const COLLECTION_SALONS = "salons";
const CLE_LIEN_SALON = "salon";
const SYSTEME = "00000000-0000-0000-0000-000000000000";
let SALON_COUT = 30;
let SALON_MEMBRES_MAX = 50;
// 10 le temps des tests (la réserve en ligne n’a que 10 questions par difficulté) ; 40 au lancement (PRD §6.2).
let SALON_QUESTIONS_MIN = 10;
let SALON_INACTIF_MS = 7 * 24 * 60 * 60 * 1000;
const SALON_NOM_MIN = 3;
const SALON_NOM_MAX = 24;
const SALON_DEVISE_MAX = 60;
const SALON_THEMES = ["fete", "paturages", "jardin"];
const SALON_COULEURS = 6;
let SALON_VICTOIRE = 10;
let SALON_DEFAITE = 5;

interface MembreSalon { userId: string; pseudo: string; score: number; depuis: number; }
interface DemandeSalon { userId: string; pseudo: string; niveau: number; quand: number; }
interface ContenuSalon { type: string; valeurs: string[]; }  // bible, testament (AT/NT), livres, categorie
interface Salon {
  id: string; nom: string; devise: string; couleur: number; theme: string; difficulte: string; contenu: ContenuSalon;
  berger: string; membres: MembreSalon[]; demandes: DemandeSalon[]; creee: number; dernierePartie: number;
}
interface LienSalon { salon: string; demande: string; }

// ---------------------------------------------------------------- Règles pures

/** La carte entre-t-elle dans le contenu du salon ? */
function carteDuSalon(c: CarteSource, difficulte: string, contenu: ContenuSalon): boolean {
  if (c.difficulty !== difficulte) return false;
  if (contenu.type === "testament") return contenu.valeurs.indexOf(c.testament || "") >= 0;
  if (contenu.type === "livres") return c.books.some(function (b) { return contenu.valeurs.indexOf(b) >= 0; });
  if (contenu.type === "categorie") return contenu.valeurs.indexOf(c.category || "") >= 0;
  return true;
}

function questionsDuSalon(cartes: CarteSource[], difficulte: string, contenu: ContenuSalon): number {
  return cartes.filter(function (c) { return carteDuSalon(c, difficulte, contenu); }).length;
}

/** Nombre de questions par critère, pour griser à l'écran les choix trop pauvres. */
function optionsSalon(cartes: CarteSource[]): any {
  const parDiff: any = {};
  DIFFICULTES.forEach(function (d) {
    const t = { total: 0, testaments: {} as any, livres: {} as any, categories: {} as any };
    cartes.forEach(function (c) {
      if (c.difficulty !== d) return;
      t.total++;
      const add = function (o: any, k: string) { o[k] = (o[k] || 0) + 1; };
      add(t.testaments, c.testament || "");
      c.books.forEach(function (b) { add(t.livres, b); });
      add(t.categories, c.category || "");
    });
    parDiff[d] = t;
  });
  return { cout: SALON_COUT, minimum: SALON_QUESTIONS_MIN, membresMax: SALON_MEMBRES_MAX, themes: SALON_THEMES, difficultes: parDiff };
}

/** "" si les paramètres de création sont bons, sinon la raison du refus. */
function verifierSalon(d: any, cartes: CarteSource[]): string {
  const nom = String(d.nom || "").trim();
  if (nom.length < SALON_NOM_MIN || nom.length > SALON_NOM_MAX) return "Le nom fait de " + SALON_NOM_MIN + " à " + SALON_NOM_MAX + " caractères.";
  if (String(d.devise || "").trim().length > SALON_DEVISE_MAX) return "La devise fait au plus " + SALON_DEVISE_MAX + " caractères.";
  if (SALON_THEMES.indexOf(String(d.theme)) < 0) return "Thème inconnu.";
  const couleur = Number(d.couleur);
  if (!(couleur >= 0 && couleur < SALON_COULEURS && Math.floor(couleur) === couleur)) return "Couleur inconnue.";
  if (DIFFICULTES.indexOf(String(d.difficulte)) < 0) return "Difficulté inconnue.";
  const c = d.contenu || {};
  if (["bible", "testament", "livres", "categorie"].indexOf(String(c.type)) < 0) return "Contenu inconnu.";
  if (c.type !== "bible" && (!Array.isArray(c.valeurs) || c.valeurs.length === 0)) return "Choisis au moins un élément.";
  if (questionsDuSalon(cartes, String(d.difficulte), { type: c.type, valeurs: c.valeurs || [] }) < SALON_QUESTIONS_MIN) return "Pas encore assez de questions.";
  return "";
}

function nouveauSalon(id: string, d: any, berger: string, pseudo: string, maintenant: number): Salon {
  return {
    id: id, nom: String(d.nom).trim(), devise: String(d.devise || "").trim(), couleur: Number(d.couleur), theme: String(d.theme),
    difficulte: String(d.difficulte), contenu: { type: String(d.contenu.type), valeurs: d.contenu.type === "bible" ? [] : d.contenu.valeurs.map(String) },
    berger: berger, membres: [{ userId: berger, pseudo: pseudo, score: 0, depuis: maintenant }], demandes: [], creee: maintenant, dernierePartie: maintenant,
  };
}

function membreIndex(s: Salon, userId: string): number {
  for (let i = 0; i < s.membres.length; i++) if (s.membres[i].userId === userId) return i;
  return -1;
}

/** Membres du meilleur score au plus faible (à égalité, le plus ancien d'abord). */
function classementSalon(s: Salon): MembreSalon[] {
  return s.membres.slice().sort(function (a, b) { return b.score - a.score || a.depuis - b.depuis; });
}

/** Rôles : Berger ; Vaillant héros et Sentinelle pour les deux premiers qui ont des points. */
function rolesSalon(s: Salon, userId: string): string[] {
  const r: string[] = [];
  if (s.berger === userId) r.push("berger");
  const c = classementSalon(s).filter(function (m) { return m.score > 0; });
  if (c.length > 0 && c[0].userId === userId) r.push("heros");
  if (c.length > 1 && c[1].userId === userId) r.push("sentinelle");
  return r;
}

/** Un membre part : s'il était Berger, le premier du classement le devient. Renvoie false si le salon est vide. */
function retirerMembre(s: Salon, userId: string): boolean {
  const i = membreIndex(s, userId);
  if (i >= 0) s.membres.splice(i, 1);
  if (s.membres.length === 0) return false;
  if (s.berger === userId) s.berger = classementSalon(s)[0].userId;
  return true;
}

/** Score de salon après une partie : +10 par victoire, −5 par défaite, jamais sous 0. */
function scoreApresPartie(score: number, gagne: boolean): number {
  return gagne ? score + SALON_VICTOIRE : Math.max(0, score - SALON_DEFAITE);
}

/** Le matchmaker reçoit l'identifiant du salon sans tirets (propriété « salon »). */
function idDepuisMarque(marque: string): string {
  return marque.replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/, "$1-$2-$3-$4-$5");
}

/** Applique le résultat d'une partie aux membres encore présents du salon. */
function appliquerResultat(s: Salon, userIds: string[], gagnant: number, maintenant: number): void {
  userIds.forEach(function (id, i) {
    const k = membreIndex(s, id);
    if (k >= 0) s.membres[k].score = scoreApresPartie(s.membres[k].score, i === gagnant);
  });
  s.dernierePartie = maintenant;
}

function salonInactif(s: Salon, maintenant: number): boolean {
  return maintenant - s.dernierePartie > SALON_INACTIF_MS;
}

/** Ce que la liste montre d'un salon. */
function resumeSalon(s: Salon): any {
  const pseudoBerger = s.membres.filter(function (m) { return m.userId === s.berger; }).map(function (m) { return m.pseudo; })[0] || "";
  return {
    id: s.id, nom: s.nom, devise: s.devise, couleur: s.couleur, theme: s.theme, difficulte: s.difficulte, contenu: s.contenu,
    membres: s.membres.length, max: SALON_MEMBRES_MAX, berger: pseudoBerger,
    apercu: classementSalon(s).slice(0, 3).map(function (m) { return m.pseudo; }),
  };
}

function ficheSalon(s: Salon, userId: string, lien: LienSalon): any {
  const f = resumeSalon(s);
  f.mise = mise("duel", s.difficulte);
  f.classement = classementSalon(s).map(function (m) {
    return { pseudo: m.pseudo, score: m.score, roles: rolesSalon(s, m.userId), moi: m.userId === userId };
  });
  f.membre = membreIndex(s, userId) >= 0;
  f.estBerger = s.berger === userId;
  f.demandeEnvoyee = lien.demande === s.id;
  f.autreSalon = lien.salon !== "" && lien.salon !== s.id;
  if (f.estBerger) f.demandes = s.demandes.map(function (d) { return { joueur: d.userId, pseudo: d.pseudo, niveau: d.niveau, quand: d.quand }; });
  return f;
}

// ---------------------------------------------------------------- Nakama

function lireSalon(nk: nkruntime.Nakama, id: string): { salon: Salon | null; version: string } {
  const lus = nk.storageRead([{ collection: COLLECTION_SALONS, key: id, userId: SYSTEME }]);
  // Copie profonde : la valeur lue est un objet Go vu depuis JavaScript, et un push() sur ses tableaux
  // (demandes, membres) modifie une copie jetable, perdue à l'écriture. Vu en production le 2026-11-28.
  return lus.length > 0 ? { salon: JSON.parse(JSON.stringify(lus[0].value)), version: lus[0].version } : { salon: null, version: "*" };
}

function ecritureSalon(s: Salon, version: string): nkruntime.StorageWriteRequest {
  return { collection: COLLECTION_SALONS, key: s.id, userId: SYSTEME, value: s as any, version: version, permissionRead: 0, permissionWrite: 0 };
}

function lireLien(nk: nkruntime.Nakama, userId: string): { lien: LienSalon; version: string } {
  const l = lireStockage(nk, userId, COLLECTION_JOUEUR, CLE_LIEN_SALON);
  const v = l.valeur || {};
  return { lien: { salon: String(v.salon || ""), demande: String(v.demande || "") }, version: l.version };
}

function ecritureLien(userId: string, lien: LienSalon, version: string): nkruntime.StorageWriteRequest {
  return ecriture(userId, COLLECTION_JOUEUR, CLE_LIEN_SALON, lien, version, 1);
}

/** Tous les salons encore vivants ; les salons inactifs depuis 7 jours sont supprimés au passage. */
function tousLesSalons(nk: nkruntime.Nakama, logger: nkruntime.Logger, maintenant: number): Salon[] {
  const salons: Salon[] = [];
  let curseur: string | undefined = undefined;
  for (let page = 0; page < 20; page++) {
    const r: nkruntime.StorageObjectList = nk.storageList(SYSTEME, COLLECTION_SALONS, 100, curseur);
    (r.objects || []).forEach(function (o) {
      const s = JSON.parse(JSON.stringify(o.value)) as Salon;
      if (salonInactif(s, maintenant)) supprimerSalon(nk, logger, s);
      else salons.push(s);
    });
    if (!r.cursor) break;
    curseur = r.cursor;
  }
  return salons;
}

function salonParMarque(nk: nkruntime.Nakama, marque: string): Salon | null {
  return lireSalon(nk, idDepuisMarque(marque)).salon;
}

function reglerScoreSalon(nk: nkruntime.Nakama, logger: nkruntime.Logger, salonId: string, userIds: string[], gagnant: number, maintenant: number): void {
  // Deux parties du salon peuvent finir ensemble : on relit et on réessaie.
  for (let essai = 0; essai < 3; essai++) {
    const l = lireSalon(nk, salonId);
    if (!l.salon) return;
    appliquerResultat(l.salon, userIds, gagnant, maintenant);
    try {
      nk.storageWrite([ecritureSalon(l.salon, l.version)]);
      return;
    } catch (e) {
      if (essai === 2) logger.error("Score de salon non enregistré pour %s : %s", salonId, String(e));
    }
  }
}

/** Les salons sont réservés aux comptes e-mail ou Google (PRD §5). */
function exigerCompte(nk: nkruntime.Nakama, userId: string): void {
  const compte = nk.accountGetId(userId);
  if (!compte.email && !compte.user.googleId) throw refus("Les salons demandent un compte (e-mail ou Google).", nkruntime.Codes.PERMISSION_DENIED);
}

function supprimerSalon(nk: nkruntime.Nakama, logger: nkruntime.Logger, s: Salon): void {
  try {
    nk.storageDelete([{ collection: COLLECTION_SALONS, key: s.id, userId: SYSTEME }]);
    s.membres.concat(s.demandes as any[]).forEach(function (m: any) {
      const l = lireLien(nk, m.userId);
      if (l.lien.salon === s.id || l.lien.demande === s.id) {
        nk.storageWrite([ecritureLien(m.userId, { salon: l.lien.salon === s.id ? "" : l.lien.salon, demande: l.lien.demande === s.id ? "" : l.lien.demande }, l.version)]);
      }
    });
    logger.info("Salon %s supprimé", s.id);
  } catch (e) {
    logger.warn("Suppression du salon %s : %s", s.id, String(e));
  }
}

function salonExistant(nk: nkruntime.Nakama, id: string): { salon: Salon; version: string } {
  const l = lireSalon(nk, String(id || ""));
  if (!l.salon) throw refus("Ce salon n'existe plus.", nkruntime.Codes.NOT_FOUND);
  return { salon: l.salon, version: l.version };
}

const rpcSalon: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  chargerReglages(nk, logger);
  if (!ctx.userId) throw refus("Connexion requise.", nkruntime.Codes.UNAUTHENTICATED);
  const moi = ctx.userId;
  const d = payload ? JSON.parse(payload) : {};
  const maintenant = Date.now();
  const action = String(d.action);

  if (action === "options") return JSON.stringify(optionsSalon(CARTES));

  if (action === "lister") {
    const l = lireLien(nk, moi);
    const recherche = String(d.recherche || "").trim().toLowerCase();
    let salons = tousLesSalons(nk, logger, maintenant);
    if (recherche) salons = salons.filter(function (s) { return s.nom.toLowerCase().indexOf(recherche) >= 0; });
    if (d.difficulte) salons = salons.filter(function (s) { return s.difficulte === d.difficulte; });
    salons.sort(function (a, b) {
      const ma = a.id === l.lien.salon ? 1 : 0, mb = b.id === l.lien.salon ? 1 : 0;
      return mb - ma || b.membres.length - a.membres.length || a.nom.localeCompare(b.nom);
    });
    return JSON.stringify({ salons: salons.map(resumeSalon), monSalon: l.lien.salon, maDemande: l.lien.demande });
  }

  if (action === "voir") {
    const s = salonExistant(nk, d.id).salon;
    return JSON.stringify(ficheSalon(s, moi, lireLien(nk, moi).lien));
  }

  if (action === "creer") {
    exigerCompte(nk, moi);
    const probleme = verifierSalon(d, CARTES);
    if (probleme) throw refus(probleme, nkruntime.Codes.INVALID_ARGUMENT);
    const l = lireLien(nk, moi);
    if (l.lien.salon) throw refus("Tu es déjà membre d'un salon : quitte-le pour en créer un.");
    if (talentsDe(nk, moi) < SALON_COUT) throw refus("Il faut " + SALON_COUT + " talents pour créer un salon.");
    const nom = String(d.nom).trim().toLowerCase();
    if (tousLesSalons(nk, logger, maintenant).some(function (s) { return s.nom.toLowerCase() === nom; })) throw refus("Ce nom est déjà pris.");
    const compte = nk.accountGetId(moi);
    const s = nouveauSalon(nk.uuidv4(), d, moi, compte.user.username, maintenant);
    nk.multiUpdate(null, [ecritureSalon(s, "*"), ecritureLien(moi, { salon: s.id, demande: "" }, l.version)], null,
      [{ userId: moi, changeset: { talents: -SALON_COUT }, metadata: { raison: "creation_salon" } }], true);
    return JSON.stringify(ficheSalon(s, moi, { salon: s.id, demande: "" }));
  }

  if (action === "demander") {
    exigerCompte(nk, moi);
    const l = lireLien(nk, moi);
    if (l.lien.salon) throw refus("Tu es déjà membre d'un salon.");
    const { salon: s, version } = salonExistant(nk, d.id);
    if (s.membres.length >= SALON_MEMBRES_MAX) throw refus("Ce salon est complet.");
    if (l.lien.demande && l.lien.demande !== s.id) retirerDemande(nk, l.lien.demande, moi);
    const compte = nk.accountGetId(moi);
    const niveau = niveauDepuisXp((compte.wallet && compte.wallet["xp"]) || 0).niveau;
    s.demandes = s.demandes.filter(function (x) { return x.userId !== moi; });
    s.demandes.push({ userId: moi, pseudo: compte.user.username, niveau: niveau, quand: maintenant });
    nk.storageWrite([ecritureSalon(s, version), ecritureLien(moi, { salon: "", demande: s.id }, l.version)]);
    return JSON.stringify(ficheSalon(s, moi, { salon: "", demande: s.id }));
  }

  if (action === "annuler_demande") {
    const l = lireLien(nk, moi);
    if (l.lien.demande) retirerDemande(nk, l.lien.demande, moi);
    nk.storageWrite([ecritureLien(moi, { salon: l.lien.salon, demande: "" }, l.version)]);
    return JSON.stringify({ ok: true });
  }

  if (action === "repondre") {
    const { salon: s, version } = salonExistant(nk, d.id);
    if (s.berger !== moi) throw refus("Seul le Berger répond aux demandes.", nkruntime.Codes.PERMISSION_DENIED);
    const joueur = String(d.joueur || "");
    const demande = s.demandes.filter(function (x) { return x.userId === joueur; })[0];
    if (!demande) throw refus("Cette demande n'existe plus.", nkruntime.Codes.NOT_FOUND);
    s.demandes = s.demandes.filter(function (x) { return x.userId !== joueur; });
    const l = lireLien(nk, joueur);
    const ecritures = [ecritureSalon(s, version)];
    const ajoute = !!d.accepte && !l.lien.salon;
    if (ajoute) {
      if (s.membres.length >= SALON_MEMBRES_MAX) throw refus("Le salon est complet.");
      s.membres.push({ userId: joueur, pseudo: demande.pseudo, score: 0, depuis: maintenant });
      ecritures.push(ecritureLien(joueur, { salon: s.id, demande: "" }, l.version));
    } else if (l.lien.demande === s.id) {
      ecritures.push(ecritureLien(joueur, { salon: l.lien.salon, demande: "" }, l.version));
    }
    nk.storageWrite(ecritures);
    // Accepté mais déjà membre ailleurs : rien à annoncer, le Berger en est informé.
    if (d.accepte && !ajoute) throw refus("Ce joueur a rejoint un autre salon entre-temps.");
    try {
      nk.notificationSend(joueur, ajoute ? "Bienvenue au salon" : "Demande refusée", { salon: s.id, nom: s.nom, accepte: ajoute }, 100, SYSTEME, true);
    } catch (e) { logger.warn("Notification de salon : %s", String(e)); }
    return JSON.stringify(ficheSalon(s, moi, lireLien(nk, moi).lien));
  }

  if (action === "quitter") {
    const l = lireLien(nk, moi);
    if (!l.lien.salon) return JSON.stringify({ ok: true });
    const lu = lireSalon(nk, l.lien.salon);
    const ecritures = [ecritureLien(moi, { salon: "", demande: l.lien.demande }, l.version)];
    if (lu.salon) {
      if (retirerMembre(lu.salon, moi)) ecritures.push(ecritureSalon(lu.salon, lu.version));
      else nk.storageDelete([{ collection: COLLECTION_SALONS, key: lu.salon.id, userId: SYSTEME, version: lu.version }]);
    }
    nk.storageWrite(ecritures);
    return JSON.stringify({ ok: true });
  }

  throw refus("Action inconnue : " + action, nkruntime.Codes.INVALID_ARGUMENT);
};

function retirerDemande(nk: nkruntime.Nakama, salonId: string, userId: string): void {
  const l = lireSalon(nk, salonId);
  if (!l.salon) return;
  l.salon.demandes = l.salon.demandes.filter(function (x) { return x.userId !== userId; });
  nk.storageWrite([ecritureSalon(l.salon, l.version)]);
}
