// Tests des règles pures du module serveur : charge build/index.js comme le fait Nakama
// (script global), puis vérifie les fonctions. Lancement : npm test (dans server/).
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

const code = fs.readFileSync(path.join(__dirname, "..", "build", "index.js"), "utf8");
const g = {};
vm.createContext(g);
vm.runInContext(code, g);

let ok = 0;
function test(nom, fn) {
  fn();
  ok++;
  console.log("  ok   " + nom);
}

const midi = Date.UTC(2026, 10, 23, 12, 0, 0);
const minuitMoinsUn = Date.UTC(2026, 10, 23, 23, 59, 59);
const lendemain = Date.UTC(2026, 10, 24, 0, 0, 1);

test("jour UTC au format AAAA-MM-JJ", function () {
  assert.strictEqual(g.jourUtc(midi), "2026-11-23");
  assert.strictEqual(g.jourUtc(Date.UTC(2026, 0, 5)), "2026-01-05");
});

test("pain disponible au premier passage", function () {
  assert.strictEqual(g.painDisponible(null, midi), true);
});

test("pain refusé le même jour, accordé le lendemain", function () {
  assert.strictEqual(g.painDisponible("2026-11-23", minuitMoinsUn), false);
  assert.strictEqual(g.painDisponible("2026-11-23", lendemain), true);
});

test("prochain pain à minuit UTC", function () {
  assert.strictEqual(g.prochainPain(midi), Date.UTC(2026, 10, 24));
});

test("mises du PRD", function () {
  assert.strictEqual(g.mise("duel", "lait"), 5);
  assert.strictEqual(g.mise("duel", "solide"), 50);
  assert.strictEqual(g.mise("arcade", "manne"), 5);
  assert.strictEqual(g.mise("arcade", "inconnue"), -1);
});

// Même table que tests/test_progression.gd.
test("niveaux selon l'XP totale", function () {
  assert.deepStrictEqual(JSON.parse(JSON.stringify(g.niveauDepuisXp(0))), { niveau: 1, dansNiveau: 0, pourSuivant: 100 });
  assert.deepStrictEqual(JSON.parse(JSON.stringify(g.niveauDepuisXp(99))), { niveau: 1, dansNiveau: 99, pourSuivant: 100 });
  assert.deepStrictEqual(JSON.parse(JSON.stringify(g.niveauDepuisXp(100))), { niveau: 2, dansNiveau: 0, pourSuivant: 150 });
  assert.deepStrictEqual(JSON.parse(JSON.stringify(g.niveauDepuisXp(700))), { niveau: 5, dansNiveau: 0, pourSuivant: 300 });
  assert.strictEqual(g.niveauDepuisXp(33250).niveau, 36);
});

test("rangs du PRD", function () {
  assert.strictEqual(g.rang(1), "Débutant");
  assert.strictEqual(g.rang(5), "Débutant");
  assert.strictEqual(g.rang(6), "Explorateur");
  assert.strictEqual(g.rang(11), "Connaisseur");
  assert.strictEqual(g.rang(21), "Expert");
  assert.strictEqual(g.rang(36), "Maître biblique");
});

test("XP d'une partie : 30 gagnée, 10 perdue, rien si abandonnée", function () {
  assert.strictEqual(g.xpDePartie(true, false), 30);
  assert.strictEqual(g.xpDePartie(false, false), 10);
  assert.strictEqual(g.xpDePartie(false, true), 0);
});

test("InitModule est défini", function () {
  assert.strictEqual(typeof g.InitModule, "function");
});

// Nakama retrouve chaque hook et RPC par son nom dans la portée globale : une fonction anonyme
// écrite dans l'appel fait refuser tout le module au démarrage (voir docs/SERVEUR.md).
test("hooks et RPC passés par des variables globales nommées", function () {
  const enregistres = [];
  const initializer = new Proxy({}, {
    get: function (_cible, methode) {
      return function () {
        Array.prototype.forEach.call(arguments, function (a) {
          if (typeof a === "function") enregistres.push({ methode: String(methode), fn: a });
          // registerMatch : chaque fonction de l'objet doit aussi être une globale nommée.
          else if (a && typeof a === "object") Object.keys(a).forEach(function (k) { enregistres.push({ methode: methode + "." + k, fn: a[k] }); });
        });
      };
    },
  });
  const logger = { info: function () {}, warn: function () {}, error: function () {}, debug: function () {} };
  g.InitModule({}, logger, { leaderboardCreate: function () {} }, initializer);
  assert.ok(enregistres.length > 0, "aucun enregistrement");
  const globales = Object.keys(g).map(function (k) { return g[k]; });
  // Les const de premier niveau ne sont pas des propriétés du contexte : on les relit par leur nom.
  const noms = code.match(/^(?:const|var|let|function)\s+([A-Za-z_$][\w$]*)/gm) || [];
  noms.forEach(function (decl) {
    const nom = decl.split(/\s+/)[1];
    globales.push(vm.runInContext("typeof " + nom + " !== 'undefined' ? " + nom + " : undefined", g));
  });
  enregistres.forEach(function (e) {
    assert.ok(globales.indexOf(e.fn) >= 0, e.methode + " reçoit une fonction anonyme");
  });
});

// ---------------------------------------------------------------- Duel : scénarios communs avec Godot

function aleaFixe(graine) {
  let s = graine;
  return function () {
    s = (s * 1103515245 + 12345) % 2147483648;
    return s / 2147483648;
  };
}

test("scénarios communs tests/scenarios/*.json", function () {
  const dossier = path.join(__dirname, "..", "..", "tests", "scenarios");
  const fichiers = fs.readdirSync(dossier).filter(function (f) { return f.endsWith(".json"); });
  assert.ok(fichiers.length > 0, "aucun scénario");
  fichiers.forEach(function (f) {
    const s = JSON.parse(fs.readFileSync(path.join(dossier, f), "utf8"));
    const alea = aleaFixe(7);
    const e = g.nouveauDuel([], [], alea);
    e.mains = s.mains.map(function (main) {
      return main.map(function (c) { return { id: c.id, reponse: c.reponse, montrees: c.montrees.slice(), reserve: c.reserve.slice() }; });
    });
    g.commencerDuel(e, s.commence);
    s.coups.forEach(function (coup) {
      g.jouer(e, coup.jouer, alea);
      g.repondre(e, coup.repondre);
    });
    assert.strictEqual(e.gagnant, s.attendu.gagnant, f + " : gagnant");
    [0, 1].forEach(function (p) {
      const obtenu = e.mains[p].map(function (c) { return { id: c.id, montrees: c.montrees, reserve: c.reserve }; });
      assert.deepStrictEqual(JSON.parse(JSON.stringify(obtenu)), s.attendu.mains[p], f + " : main " + p);
      assert.deepStrictEqual(JSON.parse(JSON.stringify(e.detruites[p])), s.attendu.detruites[p], f + " : détruites " + p);
    });
  });
});

// ---------------------------------------------------------------- IA

test("chance de l'IA selon la difficulté et les propositions restantes", function () {
  assert.strictEqual(g.chanceIA("lait", 4), 0.65);
  assert.strictEqual(g.chanceIA("manne", 4), 0.55);
  assert.strictEqual(g.chanceIA("solide", 4), 0.45);
  assert.ok(g.chanceIA("solide", 3) > 0.45 && g.chanceIA("solide", 2) > g.chanceIA("solide", 3));
  assert.ok(g.chanceIA("lait", 2) >= 0.5);
});

test("l'IA repère une proposition apparue entre deux passages", function () {
  const memoire = {};
  // Premier passage à 2 propositions : elle se trompe forcément (alea = 0,99).
  const choix = g.reponseIA("c1", ["bonne", "f1"], "bonne", "solide", memoire, function () { return 0.99; });
  assert.strictEqual(choix, "f1");
  // f1 a été remplacée par f4 : seule « bonne » était déjà là.
  assert.strictEqual(g.reponseIA("c1", ["f4", "bonne"], "bonne", "solide", memoire, function () { return 0.99; }), "bonne");
});

test("l'IA pose la carte qui a le plus de propositions", function () {
  const main = [
    { id: "a", reponse: "r", montrees: ["x"], reserve: [] },
    { id: "b", reponse: "r", montrees: ["x", "y", "z"], reserve: [] },
    { id: "c", reponse: "r", montrees: ["x", "y"], reserve: [] },
  ];
  assert.strictEqual(g.carteIA(main, Math.random), 1);
});

// ---------------------------------------------------------------- Arcade, avec un faux Nakama

function fauxNakama(talents, email) {
  const stock = {};
  const nk = {
    talents: talents,
    xp: 0,
    classement: {},
    stock: stock,
    storageRead: function (demandes) {
      const r = [];
      demandes.forEach(function (d) {
        const o = stock[d.collection + "/" + d.key];
        if (o) r.push({ value: JSON.parse(JSON.stringify(o.value)), version: o.version });
      });
      return r;
    },
    multiUpdate: function (_comptes, ecritures, _suppr, portefeuilles) {
      (ecritures || []).forEach(function (w) {
        const o = stock[w.collection + "/" + w.key];
        if (w.version && w.version !== (o ? o.version : "*")) throw new Error("version");
      });
      let total = nk.talents;
      let xp = nk.xp;
      (portefeuilles || []).forEach(function (p) { total += p.changeset.talents || 0; xp += p.changeset.xp || 0; });
      if (total < 0) throw new Error("portefeuille négatif");
      (ecritures || []).forEach(function (w) {
        const k = w.collection + "/" + w.key;
        const v = stock[k] ? String(Number(stock[k].version) + 1) : "1";
        stock[k] = { value: JSON.parse(JSON.stringify(w.value)), version: v, permissionRead: w.permissionRead };
      });
      nk.talents = total;
      nk.xp = xp;
      return { walletUpdateAcks: [{ updated: { talents: total } }] };
    },
    accountGetId: function () { return { email: email, user: { username: "testeur" }, wallet: { talents: nk.talents, xp: nk.xp } }; },
    leaderboardRecordWrite: function (id, owner, nom, score) { nk.classement[owner] = score; },
  };
  return nk;
}

const logger = { info: function () {}, warn: function () {}, error: function () {}, debug: function () {} };
vm.runInContext("var __graine = 3; Math.random = function () { __graine = (__graine * 1103515245 + 12345) % 2147483648; return __graine / 2147483648; };", g);

function appel(nk, demande) {
  return JSON.parse(g.rpcArcade({ userId: "u1" }, logger, nk, JSON.stringify(demande)));
}

function refuse(fn, morceau) {
  try { fn(); } catch (e) { assert.ok(String(e.message).indexOf(morceau) >= 0, e.message); return; }
  assert.fail("aurait dû être refusé : " + morceau);
}

test("arcade refusée aux invités, aux niveaux fermés et sans talents", function () {
  refuse(function () { appel(fauxNakama(100, ""), { action: "commencer", niveau: 1, difficulte: "lait" }); }, "compte");
  refuse(function () { appel(fauxNakama(100, "a@b.c"), { action: "commencer", niveau: 2, difficulte: "lait" }); }, "pas encore ouvert");
  refuse(function () { appel(fauxNakama(4, "a@b.c"), { action: "commencer", niveau: 1, difficulte: "solide" }); }, "Pas assez de talents");
});

/** Joue une partie complète en répondant toujours juste ; renvoie la dernière réponse du serveur. */
function partieComplete(nk, niveau, difficulte) {
  let r = appel(nk, { action: "commencer", niveau: niveau, difficulte: difficulte });
  assert.strictEqual(nk.talents, 100 - g.mise("arcade", difficulte), "mise prélevée au départ");
  for (let i = 0; i < 100 && !r.fin; i++) {
    const p = nk.stock["arcade/partie"].value;
    const v = r.vue;
    if (v.etape === "depart") r = appel(nk, { action: "depart", choix: p.depart.reponse });
    else if (v.etape === "suite") r = appel(nk, { action: "suite" });
    else if (v.etape === "choisir") r = appel(nk, { action: "jouer", index: 0 });
    else if (v.etape === "repondre") r = appel(nk, { action: "repondre", choix: p.duel.jouee.reponse });
    else assert.fail("étape inattendue : " + v.etape);
  }
  assert.ok(r.fin, "la partie se termine");
  return r;
}

test("partie d'arcade complète : mise, gain, étoile et niveau suivant", function () {
  // Le Scribe peut gagner même si le joueur répond toujours juste : on rejoue jusqu'à une victoire.
  let nk, r;
  for (let essai = 0; essai < 12; essai++) {
    nk = fauxNakama(100, "a@b.c");
    r = partieComplete(nk, 1, "manne");
    assert.strictEqual(nk.talents, r.fin.gagne ? 105 : 95, "talents après la partie");
    assert.strictEqual(nk.xp, r.fin.gagne ? 30 : 10, "XP de la partie");
    assert.strictEqual(r.fin.xpTotal, nk.xp);
    assert.strictEqual(nk.classement["u1"], nk.xp, "classement général à jour");
    assert.strictEqual(r.fin.talents, nk.talents);
    if (r.fin.gagne) break;
    assert.ok(!nk.stock["joueur/aventure"], "pas d'étoile sur une défaite");
  }
  assert.ok(r.fin.gagne, "au moins une victoire en 12 parties");
  assert.deepStrictEqual(r.fin.etoiles, ["manne"]);
  assert.strictEqual(r.fin.nouvelleEtoile, true);
  assert.strictEqual(appel(nk, { action: "etat" }).etoiles["1"][0], "manne");
  assert.strictEqual(nk.stock["joueur/aventure"].permissionRead, 1, "progression lisible par le joueur");
  assert.strictEqual(nk.stock["arcade/partie"].permissionRead, 0, "la partie (cartes de l'IA) reste cachée");
  refuse(function () { appel(nk, { action: "suite" }); }, "terminée");
  // Le niveau 2 s'ouvre.
  assert.strictEqual(appel(nk, { action: "commencer", niveau: 2, difficulte: "lait" }).vue.etape, "depart");
});

test("arcade : réponse hors délai comptée comme temps écoulé, abandon perdu", function () {
  const nk = fauxNakama(100, "a@b.c");
  let r = appel(nk, { action: "commencer", niveau: 1, difficulte: "lait" });
  for (let i = 0; i < 20 && r.vue.etape !== "repondre"; i++) {
    if (r.vue.etape === "depart") r = appel(nk, { action: "depart", choix: "" });
    else if (r.vue.etape === "suite") r = appel(nk, { action: "suite" });
    else if (r.vue.etape === "choisir") r = appel(nk, { action: "jouer", index: 0 });
    if (r.fin) return;
  }
  assert.strictEqual(r.vue.etape, "repondre");
  const entree = nk.stock["arcade/partie"];
  entree.value.echeance = Date.now() - 60000;
  const bonne = entree.value.duel.jouee.reponse;
  r = appel(nk, { action: "repondre", choix: bonne });
  assert.strictEqual(r.coup.tempsEcoule, true);
  assert.strictEqual(r.coup.juste, false);
  if (!r.fin) {
    r = appel(nk, { action: "abandonner" });
    assert.strictEqual(r.fin.gagne, false);
    assert.strictEqual(nk.talents, 98);
    assert.strictEqual(nk.xp, 0, "pas d'XP pour un abandon");
  }
});

test("arcade : le client reçoit le texte des cartes, jamais la réponse d'une carte à deviner", function () {
  const nk = fauxNakama(100, "a@b.c");
  let r = appel(nk, { action: "commencer", niveau: 1, difficulte: "lait" });
  assert.ok(r.vue.depart.question.length > 0, "texte de la question de départ");
  assert.strictEqual(r.vue.depart.id, undefined);
  assert.strictEqual(r.vue.main.length, 5);
  r.vue.main.forEach(function (c) {
    assert.ok(c.carte.question && c.carte.answer && c.carte.reference, "ses propres cartes, en entier");
  });
  assert.strictEqual(typeof appel(nk, { action: "etat" }).duChapitre["1"].lait, "boolean");
  let vues = 0;
  for (let i = 0; i < 100 && !r.fin; i++) {
    const p = nk.stock["arcade/partie"].value;
    const v = r.vue;
    if (v.etape === "depart") r = appel(nk, { action: "depart", choix: p.depart.reponse });
    else if (v.etape === "suite") r = appel(nk, { action: "suite" });
    else if (v.etape === "choisir") {
      r = appel(nk, { action: "jouer", index: 0 });
      assert.ok(r.coup.carte.answer, "sa carte jouée revient en entier");
    } else if (v.etape === "repondre") {
      const texte = JSON.stringify(v.carte);
      const bonne = p.duel.jouee.reponse;
      assert.ok(v.carte.question.length > 0 && v.carte.propositions.indexOf(bonne) >= 0);
      assert.strictEqual(v.carte.id, undefined, "pas d'identifiant");
      assert.strictEqual(v.carte.answer, undefined, "pas de réponse");
      p.duel.jouee.reserve.forEach(function (w) { assert.ok(texte.indexOf(JSON.stringify(w)) < 0, "pas de réserve"); });
      vues++;
      // Une fois sur deux, on se trompe : la carte ratée ne révèle rien.
      const fausse = v.carte.propositions.filter(function (o) { return o !== bonne; })[0];
      const choix = vues % 2 === 0 ? fausse : bonne;
      r = appel(nk, { action: "repondre", choix: choix });
      if (r.coup.juste) assert.strictEqual(r.coup.carte.answer, bonne, "carte trouvée : révélée");
      else assert.strictEqual(r.coup.carte, null, "carte ratée : rien de révélé");
    }
  }
  assert.ok(vues > 0, "au moins une carte du Scribe à deviner");
  r.vue.detruites.forEach(function (liste) {
    liste.forEach(function (c) { assert.ok(c.answer, "les cartes détruites sont révélées"); });
  });
});

test("les données embarquées couvrent la carte d'aventure", function () {
  assert.ok(vm.runInContext("CARTES.length", g) >= 30);
  assert.ok(vm.runInContext("QUESTIONS_DEPART.length", g) > 0);
  assert.strictEqual(vm.runInContext("AVENTURE.chapitres[0].niveaux.length", g), 8);
});

// ---------------------------------------------------------------- Duels en ligne : règles pures

const OP = { DEPART: 1, JOUER: 2, REPONDRE: 3, CONTINUER: 4, ABANDONNER: 5, REVANCHE: 6 };
const T0 = 1000000;

/** Partie rapide entre a et b, distribuée, à la question de départ. */
function duelPret(alea) {
  const p = g.nouvellePartieDuel("rapide", "lait", "", "", ["a", "b"], T0);
  g.arriveeDuel(p, "a", "Alpha", 1, T0);
  const effets = g.arriveeDuel(p, "b", "Bravo", 2, T0);
  assert.deepStrictEqual(types(effets), ["demarrer"]);
  g.demarrerDuel(p, {}, T0, alea);
  return p;
}

function types(effets) { return Array.from(effets, function (e) { return e.type; }); }

test("duel en ligne : arrivées acceptées ou refusées", function () {
  const p = g.nouvellePartieDuel("rapide", "lait", "", "", ["a", "b"], T0);
  assert.strictEqual(g.accepterArrivee(p, "a"), "");
  assert.ok(g.accepterArrivee(p, "z").indexOf("attend") >= 0, "un inconnu n'entre pas en duel rapide");
  const ami = g.nouvellePartieDuel("ami", "manne", "ABC234", "a", [], T0);
  assert.strictEqual(ami.mise, 20);
  assert.ok(g.accepterArrivee(ami, "z") !== "", "le créateur entre en premier");
  g.arriveeDuel(ami, "a", "Alpha", 1, T0);
  assert.strictEqual(g.accepterArrivee(ami, "z"), "", "puis n'importe quel ami avec le code");
  g.arriveeDuel(ami, "z", "Zoé", 1, T0);
  assert.ok(g.accepterArrivee(ami, "y") !== "", "partie complète");
  // Le créateur part avant l'arrivée de l'ami : partie annulée, sans mise prélevée.
  const seul = g.nouvellePartieDuel("ami", "lait", "XYZ234", "a", [], T0);
  g.arriveeDuel(seul, "a", "Alpha", 1, T0);
  assert.deepStrictEqual(types(g.departJoueurDuel(seul, "a", T0 + 5)), ["terminer"]);
  // Duel rapide : l'adversaire n'arrive pas.
  const rapide = g.nouvellePartieDuel("rapide", "lait", "", "", ["a", "b"], T0);
  g.arriveeDuel(rapide, "a", "Alpha", 1, T0);
  assert.deepStrictEqual(types(g.ticDuel(rapide, T0 + 21000, aleaFixe(1))), ["terminer"]);
  assert.strictEqual(rapide.etape, "annulee");
});

test("duel en ligne : question de départ, pose, réponse, la réponse ratée reste secrète", function () {
  const alea = aleaFixe(5);
  const p = duelPret(alea);
  const vueA = g.vueDuel(p, 0, T0);
  assert.strictEqual(vueA.etape, "depart");
  assert.ok(vueA.depart.question.length > 0);
  assert.strictEqual(vueA.main.length, 5);
  assert.ok(vueA.main[0].carte.answer, "le joueur voit ses cartes en entier");
  assert.strictEqual(vueA.mainAdverse, 5);
  const idsB = p.duel.mains[1].map(function (c) { return c.id; });
  idsB.forEach(function (id) { assert.ok(JSON.stringify(vueA).indexOf(id) < 0, "rien des cartes de l'adversaire"); });
  // b répond faux à la question de départ : a commence.
  const fausse = p.depart.propositions.filter(function (o) { return o !== p.depart.reponse; })[0];
  g.messageDuel(p, 1, OP.DEPART, { choix: fausse }, T0 + 2000, alea);
  assert.strictEqual(p.etape, "annonce");
  assert.strictEqual(g.vueDuel(p, 0, T0 + 2000).coup.jeCommence, true);
  g.ticDuel(p, T0 + 2000 + 3000 + 1001, alea);
  assert.strictEqual(p.etape, "choisir");
  assert.strictEqual(g.vueDuel(p, 0, T0 + 6100).poseur, "moi");
  // b ne peut pas poser à la place de a.
  g.messageDuel(p, 1, OP.JOUER, { index: 0 }, T0 + 6200, alea);
  assert.strictEqual(p.etape, "choisir");
  g.messageDuel(p, 0, OP.JOUER, { index: 0 }, T0 + 6200, alea);
  assert.strictEqual(p.etape, "repondre");
  const jouee = p.duel.jouee;
  const vueB = g.vueDuel(p, 1, T0 + 6300);
  assert.strictEqual(vueB.carte.id, undefined, "pas d'identifiant");
  assert.strictEqual(vueB.carte.answer, undefined, "pas de réponse");
  assert.ok(vueB.carte.propositions.indexOf(jouee.reponse) >= 0);
  assert.strictEqual(g.vueDuel(p, 0, T0 + 6300).carte.answer, jouee.reponse, "le poseur voit sa carte");
  const rate = vueB.carte.propositions.filter(function (o) { return o !== jouee.reponse; })[0];
  g.messageDuel(p, 1, OP.REPONDRE, { choix: rate }, T0 + 7000, alea);
  assert.strictEqual(p.etape, "resultat");
  assert.strictEqual(g.vueDuel(p, 1, T0 + 7000).coup.carte.answer, undefined, "carte ratée : réponse secrète");
  assert.strictEqual(g.vueDuel(p, 0, T0 + 7000).coup.carte.answer, jouee.reponse);
  // Les deux touchent « Continuer » : c'est à b de poser.
  g.messageDuel(p, 0, OP.CONTINUER, {}, T0 + 8000, alea);
  assert.strictEqual(p.etape, "resultat");
  g.messageDuel(p, 1, OP.CONTINUER, {}, T0 + 8100, alea);
  assert.strictEqual(p.etape, "choisir");
  assert.strictEqual(g.vueDuel(p, 1, T0 + 8100).poseur, "moi");
});

test("duel en ligne : délais dépassés, carte au hasard puis temps écoulé", function () {
  const alea = aleaFixe(9);
  const p = duelPret(alea);
  g.ticDuel(p, T0 + 31001, alea);
  assert.strictEqual(p.coup.type, "nouvelle_question", "personne n'a répondu au départ");
  g.messageDuel(p, 0, OP.DEPART, { choix: p.depart.reponse }, T0 + 32000, alea);
  g.ticDuel(p, T0 + 36500, alea);
  assert.strictEqual(p.etape, "choisir");
  g.ticDuel(p, T0 + 67000, alea);
  assert.strictEqual(p.etape, "choisir", "1 s de marge pour le réseau");
  g.ticDuel(p, T0 + 68000, alea);
  assert.strictEqual(p.etape, "repondre");
  assert.strictEqual(p.coup.auHasard, true);
  g.ticDuel(p, T0 + 114500, alea);
  assert.strictEqual(p.etape, "resultat");
  assert.strictEqual(p.coup.tempsEcoule, true);
  assert.strictEqual(p.coup.juste, false);
});

/** Joue jusqu'à la fin en répondant toujours juste ; renvoie les effets de la fin. */
function jouerJusquAuBout(p, alea, t) {
  let effets = [];
  for (let k = 0; k < 200 && p.fin === null; k++) {
    t += 500;
    if (p.etape === "depart") g.messageDuel(p, 0, OP.DEPART, { choix: p.depart.reponse }, t, alea);
    else if (p.etape === "annonce") g.ticDuel(p, t + 4000, alea);
    else if (p.etape === "choisir") g.messageDuel(p, p.duel.poseur, OP.JOUER, { index: 0 }, t, alea);
    else if (p.etape === "repondre") effets = g.messageDuel(p, 1 - p.duel.poseur, OP.REPONDRE, { choix: p.duel.jouee.reponse }, t, alea);
    else if (p.etape === "resultat") { g.messageDuel(p, 0, OP.CONTINUER, {}, t, alea); g.messageDuel(p, 1, OP.CONTINUER, {}, t, alea); }
  }
  return effets;
}

test("duel en ligne : fin de partie, XP, revanche acceptée par les deux", function () {
  const alea = aleaFixe(11);
  const p = duelPret(alea);
  const effets = jouerJusquAuBout(p, alea, T0);
  assert.deepStrictEqual(types(effets), ["regler"]);
  assert.strictEqual(p.fin.raison, "cartes");
  assert.strictEqual(p.fin.xp[p.fin.gagnant], 30);
  assert.strictEqual(p.fin.xp[1 - p.fin.gagnant], 10);
  assert.strictEqual(p.etape, "resultat", "le dernier coup s'affiche avant la fin");
  g.messageDuel(p, 0, OP.CONTINUER, {}, T0 + 900000, alea);
  g.messageDuel(p, 1, OP.CONTINUER, {}, T0 + 900000, alea);
  assert.strictEqual(p.etape, "finie");
  assert.strictEqual(g.vueDuel(p, p.fin.gagnant, T0 + 900000).fin.gagne, true);
  assert.strictEqual(g.vueDuel(p, 0, T0 + 900000).revanche.possible, true);
  assert.deepStrictEqual(types(g.messageDuel(p, 0, OP.REVANCHE, { accepte: true }, T0 + 901000, alea)), []);
  assert.deepStrictEqual(types(g.messageDuel(p, 1, OP.REVANCHE, { accepte: true }, T0 + 902000, alea)), ["revanche"]);
});

test("duel en ligne : revanche sans réponse, la partie se ferme", function () {
  const alea = aleaFixe(13);
  const p = duelPret(alea);
  g.messageDuel(p, 0, OP.ABANDONNER, {}, T0 + 1000, alea);
  assert.strictEqual(p.etape, "finie");
  assert.deepStrictEqual(types(g.ticDuel(p, T0 + 1000 + 16001, alea)), ["terminer"]);
});

test("duel en ligne : abandon, défaite sans XP et mise perdue", function () {
  const alea = aleaFixe(17);
  const p = duelPret(alea);
  assert.deepStrictEqual(types(g.messageDuel(p, 1, OP.ABANDONNER, {}, T0 + 1000, alea)), ["regler"]);
  assert.strictEqual(p.fin.gagnant, 0);
  assert.strictEqual(p.fin.raison, "abandon");
  assert.deepStrictEqual(Array.from(p.fin.xp), [30, 0]);
  assert.strictEqual(g.vueDuel(p, 1, T0 + 1000).fin.gain, -5);
});

test("duel en ligne : déconnexion, pause de 30 s puis défaite de l'absent", function () {
  const alea = aleaFixe(19);
  const p = duelPret(alea);
  g.messageDuel(p, 0, OP.DEPART, { choix: p.depart.reponse }, T0 + 1000, alea);
  g.ticDuel(p, T0 + 5500, alea);
  assert.strictEqual(p.etape, "choisir");
  const echeance = p.echeance;
  g.departJoueurDuel(p, "a", T0 + 6000);
  // Le délai est gelé : rien ne se passe pendant l'absence.
  g.ticDuel(p, T0 + 20000, alea);
  assert.strictEqual(p.etape, "choisir");
  assert.strictEqual(g.vueDuel(p, 1, T0 + 20000).pause.adversaireAbsent, true);
  assert.strictEqual(g.vueDuel(p, 1, T0 + 20000).pause.reconnexion, 16);
  g.messageDuel(p, 1, OP.ABANDONNER, {}, T0 + 20000, alea);
  assert.strictEqual(p.fin.gagnant, 0, "b peut abandonner pendant la pause");
  // Autre partie : a revient à temps, le délai reprend là où il était.
  const q = duelPret(alea);
  g.messageDuel(q, 0, OP.DEPART, { choix: q.depart.reponse }, T0 + 1000, alea);
  g.ticDuel(q, T0 + 5500, alea);
  const reste = q.echeance - (T0 + 6000);
  g.departJoueurDuel(q, "a", T0 + 6000);
  g.arriveeDuel(q, "a", "Alpha", 1, T0 + 20000);
  assert.strictEqual(q.echeance, T0 + 20000 + reste);
  // a repart et ne revient pas : il perd, sans XP.
  g.departJoueurDuel(q, "a", T0 + 21000);
  assert.deepStrictEqual(types(g.ticDuel(q, T0 + 21000 + 30001, alea)), ["regler"]);
  assert.strictEqual(q.fin.raison, "deconnexion");
  assert.strictEqual(q.fin.gagnant, 1);
  assert.deepStrictEqual(Array.from(q.fin.xp), [0, 30]);
  assert.strictEqual(g.vueDuel(q, 1, T0 + 51002).revanche.possible, false);
  assert.ok(echeance > 0);
});

test("duel en ligne : les deux déconnectés, partie annulée et mises rendues", function () {
  const alea = aleaFixe(23);
  const p = duelPret(alea);
  g.departJoueurDuel(p, "a", T0 + 1000);
  g.departJoueurDuel(p, "b", T0 + 2000);
  assert.deepStrictEqual(types(g.ticDuel(p, T0 + 31002, alea)), ["rembourser", "terminer"]);
  assert.strictEqual(p.etape, "annulee");
});

// ---------------------------------------------------------------- Duels en ligne : dans Nakama

/** Faux Nakama à plusieurs joueurs, pour les parties en direct. */
function fauxNakamaDuel(talents) {
  const comptes = {};
  Object.keys(talents).forEach(function (id) { comptes[id] = { talents: talents[id], xp: 0 }; });
  const nk = {
    comptes: comptes,
    stock: {},
    classement: {},
    crees: [],
    accountGetId: function (id) { return { user: { username: "joueur-" + id }, wallet: { talents: comptes[id].talents, xp: comptes[id].xp } }; },
    walletsUpdate: function (maj) {
      maj.forEach(function (m) { if (comptes[m.userId].talents + (m.changeset.talents || 0) < 0) throw new Error("portefeuille négatif"); });
      maj.forEach(function (m) {
        comptes[m.userId].talents += m.changeset.talents || 0;
        comptes[m.userId].xp += m.changeset.xp || 0;
      });
      return [];
    },
    storageRead: function (demandes) {
      return demandes.filter(function (d) { return nk.stock[d.userId + "/" + d.collection + "/" + d.key]; }).map(function (d) {
        return nk.stock[d.userId + "/" + d.collection + "/" + d.key];
      });
    },
    storageWrite: function (ecritures) {
      ecritures.forEach(function (w) { nk.stock[w.userId + "/" + w.collection + "/" + w.key] = { value: JSON.parse(JSON.stringify(w.value)), version: "1" }; });
    },
    leaderboardRecordWrite: function (id, owner, nom, score) { nk.classement[owner] = score; },
    matchCreate: function (module, params) { nk.crees.push({ module: module, params: params }); return "match-" + nk.crees.length; },
    matchList: function () { return []; },
    binaryToString: function (b) { return b; },
  };
  return nk;
}

function fauxDispatcher() {
  const d = {
    recus: {},
    broadcastMessage: function (op, data, presences) {
      presences.forEach(function (pr) { d.recus[pr.userId] = JSON.parse(data); });
    },
    matchLabelUpdate: function () {},
  };
  return d;
}

test("duel en ligne dans Nakama : mises, partie complète, gain et XP", function () {
  const nk = fauxNakamaDuel({ a: 100, b: 100, pauvre: 3 });
  const d = fauxDispatcher();
  const proposee = g.apresAppariement({}, logger, nk, [
    { presence: { userId: "a" }, properties: { difficulte: "lait" } },
    { presence: { userId: "b" }, properties: { difficulte: "lait" } },
  ]);
  assert.strictEqual(proposee, "match-1");
  assert.strictEqual(nk.crees[0].params.attendus, "a,b");
  let p = g.duelInit({}, logger, nk, nk.crees[0].params).state;
  assert.strictEqual(g.duelEssaiArrivee({}, logger, nk, d, 0, p, { userId: "pauvre" }, {}).accept, false);
  p = g.duelArrivee({}, logger, nk, d, 0, p, [{ userId: "a" }]).state;
  p = g.duelArrivee({}, logger, nk, d, 0, p, [{ userId: "b" }]).state;
  assert.strictEqual(nk.comptes.a.talents, 95, "mise prélevée à a");
  assert.strictEqual(nk.comptes.b.talents, 95, "mise prélevée à b");
  assert.strictEqual(d.recus.a.etape, "depart");
  assert.strictEqual(d.recus.b.adversaire.pseudo, "joueur-a");
  assert.ok(nk.stock["a/parties/recentes"], "cartes récentes enregistrées");
  // On joue en envoyant les messages comme les téléphones, toujours juste.
  const msg = function (userId, op, data) { return { sender: { userId: userId }, opCode: op, data: JSON.stringify(data || {}) }; };
  const id = { 0: "a", 1: "b" };
  for (let k = 0; k < 300 && p.etape !== "finie"; k++) {
    let m = [];
    if (p.etape === "depart") m = [msg("a", OP.DEPART, { choix: p.depart.reponse })];
    else if (p.etape === "annonce") p.echeance = 1;  // on saute l'annonce
    else if (p.etape === "choisir") m = [msg(id[p.duel.poseur], OP.JOUER, { index: 0 })];
    else if (p.etape === "repondre") m = [msg(id[1 - p.duel.poseur], OP.REPONDRE, { choix: p.duel.jouee.reponse })];
    else if (p.etape === "resultat") m = [msg("a", OP.CONTINUER), msg("b", OP.CONTINUER)];
    const r = g.duelBoucle({}, logger, nk, d, k, p, m);
    assert.ok(r, "la partie reste ouverte");
    p = r.state;
  }
  assert.strictEqual(p.etape, "finie");
  const gagnant = id[p.fin.gagnant];
  const perdant = id[1 - p.fin.gagnant];
  assert.strictEqual(nk.comptes[gagnant].talents, 105, "le gagnant remporte les deux mises");
  assert.strictEqual(nk.comptes[perdant].talents, 95);
  assert.strictEqual(nk.comptes[gagnant].xp, 30);
  assert.strictEqual(nk.comptes[perdant].xp, 10);
  assert.strictEqual(nk.classement[gagnant], 30);
  assert.strictEqual(d.recus[gagnant].fin.talents, 105);
  assert.strictEqual(d.recus[gagnant].fin.gagne, true);
  // Revanche : nouvelles mises.
  p = g.duelBoucle({}, logger, nk, d, 400, p, [msg("a", OP.REVANCHE, { accepte: true }), msg("b", OP.REVANCHE, { accepte: true })]).state;
  assert.strictEqual(p.etape, "depart");
  assert.strictEqual(nk.comptes[gagnant].talents, 100);
  assert.strictEqual(nk.comptes[perdant].talents, 90);
  // Arrêt du serveur en pleine partie : mises rendues.
  g.duelFin({}, logger, nk, d, 401, p, 5);
  assert.strictEqual(nk.comptes[gagnant].talents, 105);
});

test("duel entre amis : création avec code, difficulté inconnue refusée", function () {
  const nk = fauxNakamaDuel({ a: 100 });
  const r = JSON.parse(g.rpcDuelAmi({ userId: "a" }, logger, nk, JSON.stringify({ action: "creer", difficulte: "manne" })));
  assert.strictEqual(r.code.length, 6);
  assert.strictEqual(r.mise, 20);
  assert.strictEqual(nk.crees[0].params.createur, "a");
  assert.strictEqual(JSON.parse(g.duelInit({}, logger, nk, nk.crees[0].params).label).ouvert, "oui");
  refuse(function () { g.rpcDuelAmi({ userId: "a" }, logger, nk, JSON.stringify({ action: "creer", difficulte: "x" })); }, "inconnue");
  refuse(function () { g.rpcDuelAmi({ userId: "a" }, logger, nk, JSON.stringify({ action: "voir", code: "ABC234" })); }, "Aucune partie");
});

// ---------------------------------------------------------------- Salons
function fauxNakamaSalons(talents) {
  const nk = fauxNakamaDuel(talents);
  nk.notifs = [];
  nk.uuidv4 = function () { return "salon-" + Object.keys(nk.stock).length; };
  nk.storageList = function (owner, collection) {
    const objects = Object.keys(nk.stock).filter(function (k) { return k.indexOf(owner + "/" + collection + "/") === 0; }).map(function (k) { return nk.stock[k]; });
    return { objects: objects, cursor: "" };
  };
  nk.storageDelete = function (ds) { ds.forEach(function (d) { delete nk.stock[d.userId + "/" + d.collection + "/" + d.key]; }); };
  nk.multiUpdate = function (_a, ecritures, _b, wallets) { nk.walletsUpdate(wallets); nk.storageWrite(ecritures); return {}; };
  nk.notificationSend = function (userId, sujet, contenu) { nk.notifs.push({ userId: userId, sujet: sujet, contenu: contenu }); };
  return nk;
}
const SYS = "00000000-0000-0000-0000-000000000000";
function poserSalon(nk, s) { nk.stock[SYS + "/salons/" + s.id] = { value: s, version: "1" }; }
function lienSalon(nk, id) { const o = nk.stock[id + "/joueur/salon"]; return o ? o.value : { salon: "", demande: "" }; }
const salonRpc = function (nk, userId, d) { return JSON.parse(g.rpcSalon({ userId: userId }, logger, nk, JSON.stringify(d))); };
function cartesTest(n, diff, livre) {
  const r = [];
  for (let i = 0; i < n; i++) r.push({ id: "C" + i, difficulty: diff, testament: "AT", books: [livre], category: "personnages", answer: "x", wrongs: [] });
  return r;
}

test("salons : questions comptées selon la difficulté et le contenu", function () {
  const cartes = cartesTest(45, "manne", "Psaumes").concat(cartesTest(10, "lait", "Luc"));
  assert.strictEqual(g.questionsDuSalon(cartes, "manne", { type: "bible", valeurs: [] }), 45);
  assert.strictEqual(g.questionsDuSalon(cartes, "manne", { type: "livres", valeurs: ["Psaumes", "Job"] }), 45);
  assert.strictEqual(g.questionsDuSalon(cartes, "lait", { type: "testament", valeurs: ["NT"] }), 0);
  const o = g.optionsSalon(cartes);
  assert.strictEqual(o.difficultes.manne.livres.Psaumes, 45);
  assert.strictEqual(o.minimum, g.SALON_QUESTIONS_MIN);
});

test("salons : création refusée s'il manque des questions ou si les paramètres sont faux", function () {
  const cartes = cartesTest(45, "manne", "Psaumes");
  const ok = { nom: "Les Psalmistes", devise: "", couleur: 0, theme: "fete", difficulte: "manne", contenu: { type: "livres", valeurs: ["Psaumes"] } };
  assert.strictEqual(g.verifierSalon(ok, cartes), "");
  assert.ok(g.verifierSalon(Object.assign({}, ok, { difficulte: "lait" }), cartes).indexOf("Pas encore assez") >= 0, "aucune question en lait");
  assert.ok(g.verifierSalon(Object.assign({}, ok, { contenu: { type: "livres", valeurs: ["Job"] } }), cartes).indexOf("Pas encore assez") >= 0);
  assert.ok(g.verifierSalon(Object.assign({}, ok, { nom: "ab" }), cartes).indexOf("nom") >= 0);
  assert.ok(g.verifierSalon(Object.assign({}, ok, { theme: "bois" }), cartes).indexOf("Thème") >= 0);
  assert.ok(g.verifierSalon(Object.assign({}, ok, { contenu: { type: "livres", valeurs: [] } }), cartes).indexOf("au moins") >= 0);
});

test("salons : rôles, départ du Berger, score jamais négatif", function () {
  const s = g.nouveauSalon("s1", { nom: "Bérée", couleur: 1, theme: "jardin", difficulte: "lait", contenu: { type: "bible" } }, "a", "A", 1);
  s.membres.push({ userId: "b", pseudo: "B", score: 30, depuis: 2 }, { userId: "c", pseudo: "C", score: 20, depuis: 3 });
  assert.deepStrictEqual(Array.from(g.rolesSalon(s, "a")), ["berger"]);
  assert.deepStrictEqual(Array.from(g.rolesSalon(s, "b")), ["heros"]);
  assert.deepStrictEqual(Array.from(g.rolesSalon(s, "c")), ["sentinelle"]);
  assert.strictEqual(g.retirerMembre(s, "a"), true);
  assert.strictEqual(s.berger, "b", "le premier du classement devient Berger");
  assert.strictEqual(g.scoreApresPartie(3, false), 0);
  assert.strictEqual(g.scoreApresPartie(3, true), 13);
  g.retirerMembre(s, "b");
  assert.strictEqual(g.retirerMembre(s, "c"), false, "salon vide");
});

test("salons : demande d'adhésion, acceptée par le Berger seulement", function () {
  const nk = fauxNakamaSalons({ a: 100, b: 100, c: 100 });
  const s = g.nouveauSalon("s1", { nom: "Bérée", couleur: 1, theme: "jardin", difficulte: "lait", contenu: { type: "bible" } }, "a", "joueur-a", Date.now());
  poserSalon(nk, s);
  nk.storageWrite([{ userId: "a", collection: "joueur", key: "salon", value: { salon: "s1", demande: "" } }]);
  const liste = salonRpc(nk, "b", { action: "lister" });
  assert.strictEqual(liste.salons.length, 1);
  assert.strictEqual(liste.salons[0].berger, "joueur-a");
  const f = salonRpc(nk, "b", { action: "demander", id: "s1" });
  assert.strictEqual(f.demandeEnvoyee, true);
  assert.strictEqual(lienSalon(nk, "b").demande, "s1");
  refuse(function () { salonRpc(nk, "c", { action: "repondre", id: "s1", joueur: "b", accepte: true }); }, "Berger");
  const vueBerger = salonRpc(nk, "a", { action: "voir", id: "s1" });
  assert.strictEqual(vueBerger.demandes.length, 1);
  salonRpc(nk, "a", { action: "repondre", id: "s1", joueur: "b", accepte: true });
  assert.strictEqual(lienSalon(nk, "b").salon, "s1");
  assert.strictEqual(nk.notifs[0].userId, "b");
  refuse(function () { salonRpc(nk, "b", { action: "demander", id: "s1" }); }, "déjà membre");
  salonRpc(nk, "a", { action: "quitter" });
  assert.strictEqual(nk.stock[SYS + "/salons/s1"].value.berger, "b", "b devient Berger");
});

test("salons : création avec la réserve en ligne, 30 talents prélevés, un seul salon", function () {
  const nk = fauxNakamaSalons({ a: 100, b: 20 });
  const d = { action: "creer", nom: "Les Psalmistes", devise: "Louez !", couleur: 0, theme: "paturages", difficulte: "manne", contenu: { type: "bible" } };
  const f = salonRpc(nk, "a", d);
  assert.strictEqual(f.estBerger, true);
  assert.strictEqual(f.theme, "paturages");
  assert.strictEqual(nk.comptes.a.talents, 70);
  assert.strictEqual(lienSalon(nk, "a").salon, f.id);
  refuse(function () { salonRpc(nk, "a", Object.assign({}, d, { nom: "Autre" })); }, "déjà membre");
  refuse(function () { salonRpc(nk, "b", Object.assign({}, d, { nom: "Autre" })); }, "30 talents");
  refuse(function () { salonRpc(nk, "b", d); }, "30 talents");
  refuse(function () { salonRpc(nk, "a", Object.assign({}, d, { contenu: { type: "livres", valeurs: ["Job"] } })); }, "Pas encore assez");
});

test("salons : un salon inactif depuis 7 jours disparaît de la liste", function () {
  const nk = fauxNakamaSalons({ a: 100 });
  poserSalon(nk, g.nouveauSalon("vieux", { nom: "Ancien", couleur: 0, theme: "fete", difficulte: "lait", contenu: { type: "bible" } }, "a", "A", 0));
  assert.strictEqual(salonRpc(nk, "a", { action: "lister" }).salons.length, 0);
  assert.strictEqual(nk.stock[SYS + "/salons/vieux"], undefined);
});

// ---------------------------------------------------------------- Réglages du back-office

test("réglages : les valeurs par défaut sont celles du code", function () {
  const v = g.valeursEnVigueur({});
  assert.strictEqual(v.capital_depart, g.CAPITAL_DEPART);
  assert.strictEqual(v.pain_quotidien, g.PAIN_QUOTIDIEN);
  assert.strictEqual(v.mise_duel_solide, g.MISES_DUEL.solide);
  assert.strictEqual(v.duel_repondre_s, g.DUEL_REPONDRE_S);
  assert.strictEqual(v.ia_chance_lait, Math.round(g.CHANCES_IA.lait * 100));
  assert.strictEqual(v.salon_inactif_jours * 86400000, g.SALON_INACTIF_MS);
});

test("réglages : bornes et entiers vérifiés", function () {
  assert.strictEqual(g.verifierReglage("pain_quotidien", 15), "");
  assert.ok(g.verifierReglage("pain_quotidien", -1));
  assert.ok(g.verifierReglage("mise_duel_lait", 0));
  assert.ok(g.verifierReglage("duel_repondre_s", 2.5));
  assert.ok(g.verifierReglage("duel_repondre_s", "45"));
  assert.ok(g.verifierReglage("inconnu", 1));
  // Une valeur stockée devenue invalide retombe sur le défaut.
  assert.strictEqual(g.valeursEnVigueur({ pain_quotidien: -3, xp_victoire: 40 }).pain_quotidien, 10);
  assert.strictEqual(g.valeursEnVigueur({ pain_quotidien: -3, xp_victoire: 40 }).xp_victoire, 40);
});

test("réglages : appliqués aux règles, puis remis par défaut", function () {
  // Comme Nakama après InitModule : les objets globaux sont figés.
  vm.runInContext("[MISES_DUEL, MISES_ARCADE, CHANCES_IA, REGLAGES].forEach(Object.freeze)", g);
  g.appliquerReglages(g.valeursEnVigueur({ mise_arcade_manne: 7, ia_chance_solide: 80, xp_defaite: 0 }));
  assert.strictEqual(g.mise("arcade", "manne"), 7);
  assert.strictEqual(g.CHANCES_IA.solide, 0.8);
  assert.strictEqual(g.xpDePartie(false, false), 0);
  g.appliquerReglages(g.valeursEnVigueur({}));
  assert.strictEqual(g.mise("arcade", "manne"), 5);
  assert.strictEqual(g.xpDePartie(false, false), 10);
});

// ---------------------------------------------------------------- Gestion des cartes

function copie(o) { return JSON.parse(JSON.stringify(o)); }
const semence = copie(vm.runInContext("SEMENCE", g));
const modele = semence.en_ligne.cartes[0];
function fiche(plus) { return Object.assign(copie(modele), { id: "T-001", question: "Question de test ?" }, plus); }

test("cartes : les fichiers data/ passent les contrôles et ne partagent rien", function () {
  ["en_ligne", "telephone"].forEach(function (nom) {
    const autre = semence[nom === "en_ligne" ? "telephone" : "en_ligne"];
    const r = g.appliquerFiches({ cartes: [], depart: [] }, autre, semence[nom].cartes, semence[nom].depart, false);
    assert.strictEqual(r.erreurs.join(" | "), "");
    assert.strictEqual(g.reserveInjouable(r.reserve), "");
  });
});

test("cartes : fiche invalide, doublon ou carte de l'autre réserve refusés", function () {
  const e = function (cartes) { return g.appliquerFiches(semence.en_ligne, semence.telephone, cartes, [], false).erreurs.join(" | "); };
  assert.strictEqual(e([fiche({})]), "");
  assert.ok(e([fiche({ wrongs: ["a", "b"] })]).indexOf("5 fausses") >= 0);
  assert.ok(e([fiche({ wrongs: [modele.answer, "b", "c", "d", "e"] })]).indexOf("en double") >= 0);
  assert.ok(e([fiche({ books: ["Tobie"] })]).indexOf("livre inconnu") >= 0);
  assert.ok(e([fiche({}), fiche({})]).indexOf("répété") >= 0);
  assert.ok(e([fiche({ id: semence.telephone.cartes[0].id })]).indexOf("autre réserve") >= 0);
});

test("cartes : fusionner, remplacer (corbeille) et statuts", function () {
  const n = semence.en_ligne.cartes.length;
  const ajout = g.appliquerFiches(semence.en_ligne, semence.telephone, [fiche({}), fiche({ id: modele.id, question: "Nouvelle question ?" })], [], false);
  assert.strictEqual(ajout.reserve.cartes.length, n + 1);
  assert.strictEqual(ajout.ajoutees, 1);
  assert.strictEqual(ajout.modifiees, 1);
  const rempl = g.appliquerFiches(semence.en_ligne, semence.telephone, [fiche({})], [], true);
  assert.strictEqual(rempl.retirees, n);
  assert.strictEqual(rempl.reserve.cartes.length, n + 1);
  assert.ok(g.reserveInjouable(rempl.reserve));
  const s = g.changerStatut(semence.en_ligne, [modele.id], "retiree");
  assert.strictEqual(s.changees, 1);
  assert.strictEqual(g.jouables(s.reserve).lait, g.jouables(semence.en_ligne).lait - 1);
});

test("cartes : une carte retirée n'est plus tirée mais reste lisible par id", function () {
  const r = g.changerStatut(semence.en_ligne, [modele.id], "retiree").reserve;
  vm.runInContext("[CARTES, QUESTIONS_DEPART, SEMENCE].forEach(Object.freeze)", g);
  g.installerCartes(r);
  assert.strictEqual(vm.runInContext("CARTES.filter(function (c) { return c.id === '" + modele.id + "'; }).length", g), 0);
  assert.strictEqual(g.carteComplete(modele.id).question, modele.question);
  g.installerCartes(semence.en_ligne);
});

test("structure : une carte au plus par main, sauf réserve trop pauvre", function () {
  const c = function (i, cat) { return { id: "x" + i, category: cat }; };
  const structure = Array.from({ length: 20 }, function (_, i) { return c(i, "structure"); });
  const autres = Array.from({ length: 10 }, function (_, i) { return c(100 + i, "miracles"); });
  const nb = function (m) { return m.filter(function (x) { return x.category === "structure"; }).length; };
  const mains = g.composerMains(structure.concat(autres));
  assert.strictEqual(mains[0].length + mains[1].length, 10);
  assert.strictEqual(nb(mains[0]), 1);
  assert.strictEqual(nb(mains[1]), 1);
  assert.strictEqual(new Set(mains[0].concat(mains[1]).map(function (x) { return x.id; })).size, 10);
  const pauvre = g.composerMains(structure.slice(0, 8).concat(autres.slice(0, 2)));
  assert.strictEqual(pauvre[0].length + pauvre[1].length, 10);
});

console.log("\n" + ok + " tests serveur réussis");
