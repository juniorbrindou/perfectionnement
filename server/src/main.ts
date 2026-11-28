// Point d'entrée du module Nakama de Perfectionnement (compilé dans build/index.js).
//
// Nakama retrouve chaque fonction enregistrée par son nom dans la portée globale : un hook ou un RPC se passe
// donc toujours par une variable globale nommée, jamais par une fonction anonyme écrite dans l'appel
// (sinon : « function key could not be extracted: not found » et le module entier refuse de charger).

const apresCreationCompte = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, session: nkruntime.Session): void {
  chargerReglages(nk, logger);
  if (session.created && ctx.userId) {
    crediterCapital(nk, logger, ctx.userId);
  }
};

const apresAuthAppareil: nkruntime.AfterHookFunction<nkruntime.Session, nkruntime.AuthenticateDeviceRequest> = function (ctx, logger, nk, data, _req) {
  apresCreationCompte(ctx, logger, nk, data);
};

const apresAuthEmail: nkruntime.AfterHookFunction<nkruntime.Session, nkruntime.AuthenticateEmailRequest> = function (ctx, logger, nk, data, _req) {
  apresCreationCompte(ctx, logger, nk, data);
};

const apresAuthGoogle: nkruntime.AfterHookFunction<nkruntime.Session, nkruntime.AuthenticateGoogleRequest> = function (ctx, logger, nk, data, _req) {
  apresCreationCompte(ctx, logger, nk, data);
};

function InitModule(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, initializer: nkruntime.Initializer): void {
  initializer.registerAfterAuthenticateDevice(apresAuthAppareil);
  initializer.registerAfterAuthenticateEmail(apresAuthEmail);
  initializer.registerAfterAuthenticateGoogle(apresAuthGoogle);
  initializer.registerRpc("pain_quotidien", rpcPainQuotidien);
  initializer.registerRpc("arcade", rpcArcade);
  initializer.registerRpc("duel_ami", rpcDuelAmi);
  initializer.registerRpc("salon", rpcSalon);
  initializer.registerRpc("reglages", rpcReglages);
  initializer.registerRpc("reglages_admin", rpcReglagesAdmin);
  initializer.registerMatchmakerMatched(apresAppariement);
  // Les fonctions de la partie sont, elles aussi, des variables globales nommées.
  initializer.registerMatch<PartieDuel>(MODULE_DUEL, {
    matchInit: duelInit,
    matchJoinAttempt: duelEssaiArrivee,
    matchJoin: duelArrivee,
    matchLeave: duelDepartJoueur,
    matchLoop: duelBoucle,
    matchTerminate: duelFin,
    matchSignal: duelSignal,
  });
  // Classement général par XP (créé s'il n'existe pas ; le serveur seul y écrit).
  nk.leaderboardCreate(CLASSEMENT_XP, true, nkruntime.SortOrder.DESCENDING, nkruntime.Operator.SET, null, null, true);
  logger.info("Module Perfectionnement chargé (talents, pain quotidien, arcade, XP, duels en ligne, salons, réglages).");
}

// Nakama appelle InitModule par son nom : on le garde référencé pour qu'il ne soit pas éliminé.
!InitModule && InitModule.bind(null);
