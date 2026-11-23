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

console.log("\n" + ok + " tests serveur réussis");
