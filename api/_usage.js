export async function checkAndConsumeAI(admin, companyId, amount=1){
  const qty = Math.max(1, Number(amount || 1));

  const {data,error} = await admin.rpc("vendaai_consume_ai",{
    p_company_id:companyId,
    p_amount:qty
  });

  if(error){
    const e = new Error(error.message || "Não foi possível registrar o uso da IA.");

    if(
      String(error.message||"").includes("usos grátis") ||
      String(error.message||"").includes("Limite mensal")
    ){
      e.statusCode = 429;
    }

    throw e;
  }

  const row = Array.isArray(data) ? data[0] : data;

  return {
    plan:row?.plan || "trial",
    used:Number(row?.used || 0),
    limit:Number(row?.limit_value || 0),
    remaining:Number(row?.remaining || 0)
  };
}
