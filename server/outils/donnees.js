// Copie la réserve « en ligne » (data/en_ligne/ : cartes et questions de départ, absentes de
// l'APK) et la carte d'aventure dans src/donnees.gen.ts, pour que le module Nakama les embarque
// (pas de fichier à déployer à côté de index.js). Lancé par npm run build et npm test.
const fs = require("fs");
const path = require("path");

const data = path.join(__dirname, "..", "..", "data");
const lire = function (nom) {
  return JSON.parse(fs.readFileSync(path.join(data, nom), "utf8"));
};

// Semence des deux réserves : utilisée tant que le back-office n'a rien modifié (src/cartes.ts).
const semence = {
  en_ligne: { cartes: lire("en_ligne/cartes.json"), depart: lire("en_ligne/questions_depart.json") },
  telephone: { cartes: lire("cartes.json"), depart: lire("questions_depart.json") },
};
const cartes = semence.en_ligne.cartes;
const depart = semence.en_ligne.depart;
const aventure = lire("aventure.json");

const sortie =
  "// Généré par outils/donnees.js depuis data/ : ne pas modifier à la main.\n" +
  "const SEMENCE: { [reserve: string]: { cartes: any[]; depart: any[] } } = " + JSON.stringify(semence) + ";\n" +
  "let CARTES: CarteSource[] = SEMENCE.en_ligne.cartes;\n" +
  "let QUESTIONS_DEPART: QuestionDepartSource[] = SEMENCE.en_ligne.depart;\n" +
  "let CARTES_TOUTES: CarteSource[] = SEMENCE.en_ligne.cartes;\n" +
  "let DEPART_TOUTES: QuestionDepartSource[] = SEMENCE.en_ligne.depart;\n" +
  "const AVENTURE: AventureSource = " + JSON.stringify(aventure) + ";\n";

fs.writeFileSync(path.join(__dirname, "..", "src", "donnees.gen.ts"), sortie);
console.log("donnees.gen.ts : " + cartes.length + " cartes, " + depart.length + " questions de départ");
