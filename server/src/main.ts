// Point d'entrée du module Nakama de Perfectionnement (compilé dans build/index.js).

const apresCreationCompte = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, session: nkruntime.Session): void {
  if (session.created && ctx.userId) {
    crediterCapital(nk, logger, ctx.userId);
  }
};

function InitModule(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, initializer: nkruntime.Initializer): void {
  initializer.registerAfterAuthenticateDevice(function (c, l, n, data, _req) { apresCreationCompte(c, l, n, data); });
  initializer.registerAfterAuthenticateEmail(function (c, l, n, data, _req) { apresCreationCompte(c, l, n, data); });
  initializer.registerAfterAuthenticateGoogle(function (c, l, n, data, _req) { apresCreationCompte(c, l, n, data); });
  initializer.registerRpc("pain_quotidien", rpcPainQuotidien);
  logger.info("Module Perfectionnement chargé (talents, pain quotidien).");
}

// Nakama appelle InitModule par son nom : on le garde référencé pour qu'il ne soit pas éliminé.
!InitModule && InitModule.bind(null);
