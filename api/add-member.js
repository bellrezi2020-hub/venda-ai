import { requireCompanyAccess, apiError } from "./_auth.js";

export default async function handler(req,res){
  if(req.method!=="POST") return res.status(405).json({erro:"Método não permitido"});
  try{
    const {companyId,email,fullName}=req.body || {};
    if(!companyId || !email) return res.status(400).json({erro:"Empresa e e-mail são obrigatórios."});
    const {admin}=await requireCompanyAccess(req,companyId,{ownerOnly:true});
    const {data,error}=await admin.auth.admin.listUsers();
    if(error) throw error;
    const user=data.users.find(u=>u.email?.toLowerCase()===String(email).trim().toLowerCase());
    if(!user) return res.status(404).json({erro:"Esse e-mail ainda não criou conta no VendaAI."});
    await admin.from("profiles").upsert({id:user.id,email:user.email,full_name:fullName?.trim() || user.email});
    const {error:e2}=await admin.from("company_members").upsert({company_id:companyId,user_id:user.id,role:"corretor"},{onConflict:"company_id,user_id"});
    if(e2) throw e2;
    return res.status(200).json({ok:true});
  }catch(e){ return apiError(res,e); }
}
