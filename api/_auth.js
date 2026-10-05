import { createClient } from "@supabase/supabase-js";

function getAdmin(){
  const url=process.env.SUPABASE_URL;
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url || !key) throw new Error("Supabase server credentials ausentes.");
  return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
}

export async function requireUser(req){
  const raw=req.headers.authorization || "";
  const token=raw.startsWith("Bearer ") ? raw.slice(7) : null;
  if(!token) throw Object.assign(new Error("Não autenticado."),{statusCode:401});
  const admin=getAdmin();
  const {data,error}=await admin.auth.getUser(token);
  if(error || !data?.user) throw Object.assign(new Error("Sessão inválida."),{statusCode:401});
  return {admin,user:data.user};
}

export async function requireCompanyAccess(req,companyId,{ownerOnly=false}={}){
  const {admin,user}=await requireUser(req);
  const {data:company}=await admin.from("companies").select("*").eq("id",companyId).maybeSingle();
  if(!company) throw Object.assign(new Error("Empresa não encontrada."),{statusCode:404});
  if(company.owner_id===user.id) return {admin,user,company,isOwner:true};
  if(ownerOnly) throw Object.assign(new Error("Apenas o administrador pode executar esta ação."),{statusCode:403});
  const {data:member}=await admin.from("company_members").select("role").eq("company_id",companyId).eq("user_id",user.id).maybeSingle();
  if(!member) throw Object.assign(new Error("Sem acesso a esta empresa."),{statusCode:403});
  return {admin,user,company,isOwner:false,role:member.role};
}

export async function requireLeadAccess(req,leadId){
  const {admin,user}=await requireUser(req);
  const {data:lead}=await admin.from("leads").select("*,companies:company_id(owner_id)").eq("id",leadId).maybeSingle();
  if(!lead) throw Object.assign(new Error("Lead não encontrado."),{statusCode:404});
  if(lead.companies?.owner_id===user.id) return {admin,user,lead,isOwner:true};
  if(lead.assigned_to!==user.id) throw Object.assign(new Error("Este lead não está atribuído a você."),{statusCode:403});
  return {admin,user,lead,isOwner:false};
}

export function apiError(res,e){
  console.error(e);
  return res.status(e.statusCode || 500).json({erro:e.message || "Erro interno."});
}
