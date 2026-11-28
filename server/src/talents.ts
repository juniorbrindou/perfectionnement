// Talents (PRD §4) : capital de départ et pain quotidien. Le portefeuille Nakama
// (clé « talents ») n'est jamais modifié par le client.

const COLLECTION_JOUEUR = "joueur";
const CLE_PAIN = "pain";

/** Crédite le capital de départ à la création d'un compte (invité ou e-mail). */
function crediterCapital(nk: nkruntime.Nakama, logger: nkruntime.Logger, userId: string): void {
  nk.walletUpdate(userId, { talents: CAPITAL_DEPART }, { raison: "capital_depart" }, true);
  logger.info("Capital de départ crédité à %s", userId);
}

/**
 * RPC « pain_quotidien » : +10 talents une fois par jour UTC.
 * Réponse : { accorde, gain, talents, prochain } (prochain = ms du prochain pain).
 * La lecture puis l'écriture conditionnelle (version) empêchent de le prendre deux fois.
 */
const rpcPainQuotidien: nkruntime.RpcFunction = function (ctx, logger, nk, _payload) {
  chargerReglages(nk, logger);
  if (!ctx.userId) {
    throw { message: "Connexion requise.", code: nkruntime.Codes.UNAUTHENTICATED } as nkruntime.Error;
  }
  const maintenant = Date.now();
  const lus = nk.storageRead([{ collection: COLLECTION_JOUEUR, key: CLE_PAIN, userId: ctx.userId }]);
  const dernier = lus.length > 0 ? (lus[0].value["jour"] as string) : null;
  const talentsActuels = function (): number {
    const compte = nk.accountGetId(ctx.userId!);
    return (compte.wallet && compte.wallet["talents"]) || 0;
  };
  if (!painDisponible(dernier, maintenant)) {
    return JSON.stringify({ accorde: false, gain: 0, talents: talentsActuels(), prochain: prochainPain(maintenant) });
  }
  try {
    const res = nk.multiUpdate(
      null,
      [{
        collection: COLLECTION_JOUEUR,
        key: CLE_PAIN,
        userId: ctx.userId,
        value: { jour: jourUtc(maintenant) },
        version: lus.length > 0 ? lus[0].version : "*",
        permissionRead: 1,
        permissionWrite: 0,
      }],
      null,
      [{ userId: ctx.userId, changeset: { talents: PAIN_QUOTIDIEN }, metadata: { raison: "pain_quotidien" } }],
      true,
    );
    const talents = res.walletUpdateAcks[0].updated["talents"];
    return JSON.stringify({ accorde: true, gain: PAIN_QUOTIDIEN, talents: talents, prochain: prochainPain(maintenant) });
  } catch (e) {
    // Écriture concurrente (deux appels simultanés) : le premier a déjà pris le pain.
    logger.warn("Pain quotidien refusé pour %s : %s", ctx.userId, String(e));
    return JSON.stringify({ accorde: false, gain: 0, talents: talentsActuels(), prochain: prochainPain(maintenant) });
  }
};
