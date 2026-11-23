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

console.log("\n" + ok + " tests serveur réussis");
