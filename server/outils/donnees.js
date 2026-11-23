// Copie les cartes, les questions de départ et la carte d'aventure de data/ dans
// src/donnees.gen.ts, pour que le module Nakama les embarque (pas de fichier à déployer
// à côté de index.js). Lancé par npm run build et npm test.
const fs = require("fs");
const path = require("path");

const data = path.join(__dirname, "..", "..", "data");
const lire = function (nom) {
  return JSON.parse(fs.readFileSync(path.join(data, nom), "utf8"));
};

const cartes = lire("cartes.json").map(function (c) {
  return { id: c.id, difficulty: c.difficulty, books: c.books, answer: c.answer, wrongs: c.wrongs };
});
const depart = lire("questions_depart.json").map(function (q) {
  return { id: q.id, answer: q.answer, wrongs: q.wrongs };
});
const aventure = lire("aventure.json");

const sortie =
  "// Généré par outils/donnees.js depuis data/ : ne pas modifier à la main.\n" +
  "const CARTES: CarteSource[] = " + JSON.stringify(cartes) + ";\n" +
  "const QUESTIONS_DEPART: QuestionDepartSource[] = " + JSON.stringify(depart) + ";\n" +
  "const AVENTURE: AventureSource = " + JSON.stringify(aventure) + ";\n";

fs.writeFileSync(path.join(__dirname, "..", "src", "donnees.gen.ts"), sortie);
console.log("donnees.gen.ts : " + cartes.length + " cartes, " + depart.length + " questions de départ");
