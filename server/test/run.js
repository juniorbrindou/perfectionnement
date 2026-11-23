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
        const fn = Array.prototype.find.call(arguments, function (a) { return typeof a === "function"; });
        enregistres.push({ methode: String(methode), fn: fn });
      };
    },
  });
  const logger = { info: function () {}, warn: function () {}, error: function () {}, debug: function () {} };
  g.InitModule({}, logger, {}, initializer);
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
      (portefeuilles || []).forEach(function (p) { total += p.changeset.talents; });
      if (total < 0) throw new Error("portefeuille négatif");
      (ecritures || []).forEach(function (w) {
        const k = w.collection + "/" + w.key;
        const v = stock[k] ? String(Number(stock[k].version) + 1) : "1";
        stock[k] = { value: JSON.parse(JSON.stringify(w.value)), version: v, permissionRead: w.permissionRead };
      });
      nk.talents = total;
      return { walletUpdateAcks: [{ updated: { talents: total } }] };
    },
    accountGetId: function () { return { email: email, user: {}, wallet: { talents: nk.talents } }; },
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
  }
});

test("les données embarquées couvrent la carte d'aventure", function () {
  assert.ok(vm.runInContext("CARTES.length", g) >= 30);
  assert.ok(vm.runInContext("QUESTIONS_DEPART.length", g) > 0);
  assert.strictEqual(vm.runInContext("AVENTURE.chapitres[0].niveaux.length", g), 8);
});

console.log("\n" + ok + " tests serveur réussis");
