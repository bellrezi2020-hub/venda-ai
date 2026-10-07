const DEFAULT_MONTHLY_LIMIT = 500;

function monthKey(){
  return new Date().toISOString().slice(0,7);
}

export async function checkAndConsumeAI(admin, companyId, amount=1){
  const month = monthKey();

  const {data:limitRow,error:limitError} = await admin
    .from("company_limits")
    .select("monthly_ai_limit,plan")
    .eq("company_id",companyId)
    .maybeSingle();

  if(limitError) throw limitError;

  const limit = Number(limitRow?.monthly_ai_limit || DEFAULT_MONTHLY_LIMIT);

  const {data:usage,error:usageError} = await admin
    .from("ai_usage")
    .select("id,requests")
    .eq("company_id",companyId)
    .eq("month",month)
    .maybeSingle();

  if(usageError) throw usageError;

  const current = Number(usage?.requests || 0);

  if(current + amount > limit){
    const e = new Error("Limite mensal de IA atingido para esta empresa.");
    e.statusCode = 429;
    throw e;
  }

  if(usage?.id){
    const {error}=await admin
      .from("ai_usage")
      .update({requests: current + amount, updated_at: new Date().toISOString()})
      .eq("id",usage.id);
    if(error) throw error;
  }else{
    const {error}=await admin
      .from("ai_usage")
      .insert({company_id:companyId, month, requests:amount});
    if(error) throw error;
  }

  return {used: current + amount, limit, remaining: Math.max(limit - (current + amount),0)};
}
