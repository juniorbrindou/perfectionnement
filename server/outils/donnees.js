// Copie la réserve « en ligne » (data/en_ligne/ : cartes et questions de départ, absentes de
// l'APK) et la carte d'aventure dans src/donnees.gen.ts, pour que le module Nakama les embarque
// (pas de fichier à déployer à côté de index.js). Lancé par npm run build et npm test.
const fs = require("fs");
const path = require("path");

const data = path.join(__dirname, "..", "..", "data");
const lire = function (nom) {
  return JSON.parse(fs.readFileSync(path.join(data, nom), "utf8"));
};

const cartes = lire("en_ligne/cartes.json").map(function (c) {
  return {
    id: c.id, difficulty: c.difficulty, testament: c.testament, books: c.books, category: c.category,
    question: c.question, answer: c.answer, wrongs: c.wrongs, reference: c.reference,
    explanation: c.explanation, story: c.story,
  };
});
const depart = lire("en_ligne/questions_depart.json").map(function (q) {
  return { id: q.id, question: q.question, answer: q.answer, wrongs: q.wrongs };
});
const aventure = lire("aventure.json");

const sortie =
  "// Généré par outils/donnees.js depuis data/ : ne pas modifier à la main.\n" +
  "const CARTES: CarteSource[] = " + JSON.stringify(cartes) + ";\n" +
  "const QUESTIONS_DEPART: QuestionDepartSource[] = " + JSON.stringify(depart) + ";\n" +
  "const AVENTURE: AventureSource = " + JSON.stringify(aventure) + ";\n";

fs.writeFileSync(path.join(__dirname, "..", "src", "donnees.gen.ts"), sortie);
console.log("donnees.gen.ts : " + cartes.length + " cartes, " + depart.length + " questions de départ");
