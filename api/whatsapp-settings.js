import { requireCompanyAccess, apiError } from "./_auth.js";

export default async function handler(req,res){
  try{
    if(req.method === "GET"){
      const companyId = String(req.query?.companyId || "");
      if(!companyId) return res.status(400).json({erro:"Empresa não informada."});

      const {admin} = await requireCompanyAccess(req,companyId,{ownerOnly:true});

      const {data,error} = await admin
        .from("whatsapp_connections")
        .select("company_id,phone_number_id,waba_id,display_phone_number,enabled,auto_reply,updated_at")
        .eq("company_id",companyId)
        .maybeSingle();

      if(error) throw error;

      return res.status(200).json({
        connection:data || null,
        server:{
          accessToken:Boolean(process.env.WHATSAPP_ACCESS_TOKEN),
          verifyToken:Boolean(process.env.WHATSAPP_VERIFY_TOKEN),
          appSecret:Boolean(process.env.META_APP_SECRET),
          graphVersion:Boolean(process.env.META_GRAPH_VERSION)
        }
      });
    }

    if(req.method === "POST"){
      const {
        companyId,
        phoneNumberId,
        wabaId,
        displayPhoneNumber,
        enabled=false
      } = req.body || {};

      if(!companyId) return res.status(400).json({erro:"Empresa não informada."});
      if(!String(phoneNumberId||"").trim())
        return res.status(400).json({erro:"Phone Number ID é obrigatório."});

      const {admin} = await requireCompanyAccess(req,companyId,{ownerOnly:true});

      const wantsEnabled = Boolean(enabled);

      if(wantsEnabled){
        const missing = [];
        if(!process.env.WHATSAPP_ACCESS_TOKEN) missing.push("WHATSAPP_ACCESS_TOKEN");
        if(!process.env.WHATSAPP_VERIFY_TOKEN) missing.push("WHATSAPP_VERIFY_TOKEN");
        if(!process.env.META_APP_SECRET) missing.push("META_APP_SECRET");
        if(!process.env.META_GRAPH_VERSION) missing.push("META_GRAPH_VERSION");

        if(missing.length){
          return res.status(400).json({
            erro:`Antes de ativar, configure na Vercel: ${missing.join(", ")}.`
          });
        }
      }

      const payload = {
        company_id:companyId,
        phone_number_id:String(phoneNumberId).trim(),
        waba_id:String(wabaId||"").trim() || null,
        display_phone_number:String(displayPhoneNumber||"").trim() || null,
        enabled:wantsEnabled,
        auto_reply:false,
        updated_at:new Date().toISOString()
      };

      const {data,error} = await admin
        .from("whatsapp_connections")
        .upsert(payload,{onConflict:"company_id"})
        .select("company_id,phone_number_id,waba_id,display_phone_number,enabled,auto_reply,updated_at")
        .single();

      if(error) throw error;

      return res.status(200).json({ok:true,connection:data});
    }

    return res.status(405).json({erro:"Método não permitido"});
  }catch(e){
    return apiError(res,e);
  }
}
