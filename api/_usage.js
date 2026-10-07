const PLAN_LIMITS = {
  trial: 3,
  starter: 300,
  pro: 1500
};

function monthKey(){
  return new Date().toISOString().slice(0,7);
}

export async function checkAndConsumeAI(admin, companyId, amount=1){
  const {data:limitRow,error:limitError} = await admin
    .from("company_limits")
    .select("monthly_ai_limit,plan")
    .eq("company_id",companyId)
    .maybeSingle();

  if(limitError) throw limitError;

  const plan = String(limitRow?.plan || "trial").toLowerCase();
  const configured = Number(limitRow?.monthly_ai_limit || 0);
  const planLimit = PLAN_LIMITS[plan] || configured || 300;

  if(plan === "trial"){
    const {data:allUsage,error:allUsageError} = await admin
      .from("ai_usage")
      .select("requests")
      .eq("company_id",companyId);

    if(allUsageError) throw allUsageError;

    const usedLifetime = (allUsage || [])
      .reduce((sum,row)=>sum + Number(row.requests||0),0);

    if(usedLifetime + amount > 3){
      const e = new Error("Os 3 usos grátis da IA foram utilizados.");
      e.statusCode = 429;
      throw e;
    }
  }

  const month = monthKey();

  const {data:usage,error:usageError} = await admin
    .from("ai_usage")
    .select("id,requests")
    .eq("company_id",companyId)
    .eq("month",month)
    .maybeSingle();

  if(usageError) throw usageError;

  const current = Number(usage?.requests || 0);

  if(plan !== "trial" && current + amount > planLimit){
    const e = new Error("Limite mensal de IA atingido para este plano.");
    e.statusCode = 429;
    throw e;
  }

  if(usage?.id){
    const {error}=await admin
      .from("ai_usage")
      .update({
        requests: current + amount,
        updated_at: new Date().toISOString()
      })
      .eq("id",usage.id);

    if(error) throw error;
  }else{
    const {error}=await admin
      .from("ai_usage")
      .insert({
        company_id:companyId,
        month,
        requests:amount
      });

    if(error) throw error;
  }

  return {
    plan,
    used: current + amount,
    limit: plan === "trial" ? 3 : planLimit,
    remaining: Math.max((plan === "trial" ? 3 : planLimit) - (current + amount),0)
  };
}
