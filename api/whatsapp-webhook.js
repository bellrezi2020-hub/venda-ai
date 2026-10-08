import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";

export const config = {
  api:{bodyParser:false}
};

function getAdmin(){
  const url=process.env.SUPABASE_URL;
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url || !key) throw new Error("Supabase server credentials ausentes.");
  return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
}

async function rawBody(req){
  const chunks=[];
  for await (const chunk of req) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

function signatureOk(raw,signature){
  const secret=process.env.META_APP_SECRET;
  if(!secret) return false;
  if(!signature?.startsWith("sha256=")) return false;

  const expected="sha256="+crypto
    .createHmac("sha256",secret)
    .update(raw)
    .digest("hex");

  const a=Buffer.from(expected);
  const b=Buffer.from(signature);

  return a.length===b.length && crypto.timingSafeEqual(a,b);
}

function cleanPhone(v){
  return String(v||"").replace(/\D/g,"");
}

async function saveInbound(admin,connection,value,message){
  const from=cleanPhone(message.from);
  if(!from || !message.id) return;

  const {data:existingMessage}=await admin
    .from("messages")
    .select("id")
    .eq("external_id",message.id)
    .maybeSingle();

  if(existingMessage) return;

  const contact=(value.contacts||[]).find(c=>cleanPhone(c.wa_id)===from);
  const contactName=contact?.profile?.name || `WhatsApp ${from}`;

  let {data:lead,error:leadError}=await admin
    .from("leads")
    .select("*")
    .eq("company_id",connection.company_id)
    .eq("whatsapp_contact_id",from)
    .maybeSingle();

  if(leadError) throw leadError;

  const text =
    message.type==="text"
      ? String(message.text?.body||"").trim()
      : `[Mensagem do WhatsApp do tipo ${message.type||"desconhecido"}]`;

  if(!lead){
    const inserted=await admin
      .from("leads")
      .insert({
        company_id:connection.company_id,
        name:contactName,
        phone:from,
        whatsapp_contact_id:from,
        source:"whatsapp",
        original_message:text,
        temperature:"Morno",
        intent:"Novo contato pelo WhatsApp",
        suggested_reply:"",
        next_step:"Analisar a mensagem recebida.",
        status:"Novo",
        match_count:0,
        matches:[],
        last_activity_at:new Date().toISOString()
      })
      .select("*")
      .single();

    if(inserted.error) throw inserted.error;
    lead=inserted.data;
  }else{
    await admin
      .from("leads")
      .update({
        phone:lead.phone || from,
        source:"whatsapp",
        last_activity_at:new Date().toISOString()
      })
      .eq("id",lead.id);
  }

  const insertMessage=await admin
    .from("messages")
    .insert({
      lead_id:lead.id,
      role:"user",
      content:text,
      channel:"whatsapp",
      direction:"inbound",
      external_id:message.id,
      delivery_status:"received"
    });

  if(insertMessage.error) throw insertMessage.error;
}

async function updateStatuses(admin,value){
  for(const status of value.statuses||[]){
    const externalId=status.id;
    if(!externalId) continue;

    await admin
      .from("messages")
      .update({delivery_status:status.status||null})
      .eq("external_id",externalId);
  }
}

export default async function handler(req,res){
  try{
    if(req.method==="GET"){
      const mode=String(req.query?.["hub.mode"]||"");
      const token=String(req.query?.["hub.verify_token"]||"");
      const challenge=String(req.query?.["hub.challenge"]||"");

      if(
        mode==="subscribe" &&
        process.env.WHATSAPP_VERIFY_TOKEN &&
        token===process.env.WHATSAPP_VERIFY_TOKEN
      ){
        res.status(200).send(challenge);
        return;
      }

      res.status(403).send("Verification failed");
      return;
    }

    if(req.method!=="POST"){
      res.status(405).json({erro:"Método não permitido"});
      return;
    }

    const raw=await rawBody(req);
    const signature=req.headers["x-hub-signature-256"];

    if(!signatureOk(raw,signature)){
      res.status(401).json({erro:"Assinatura inválida."});
      return;
    }

    let body;
    try{
      body=JSON.parse(raw.toString("utf8"));
    }catch{
      res.status(400).json({erro:"JSON inválido."});
      return;
    }

    if(body.object!=="whatsapp_business_account"){
      res.status(200).json({ok:true});
      return;
    }

    const admin=getAdmin();

    for(const entry of body.entry||[]){
      for(const change of entry.changes||[]){
        if(change.field!=="messages") continue;

        const value=change.value||{};
        const phoneNumberId=String(value.metadata?.phone_number_id||"");

        if(!phoneNumberId) continue;

        const {data:connection,error}=await admin
          .from("whatsapp_connections")
          .select("*")
          .eq("phone_number_id",phoneNumberId)
          .eq("enabled",true)
          .maybeSingle();

        if(error) throw error;
        if(!connection) continue;

        await updateStatuses(admin,value);

        for(const message of value.messages||[]){
          await saveInbound(admin,connection,value,message);
        }
      }
    }

    res.status(200).json({ok:true});
  }catch(e){
    console.error(e);
    // Webhooks devem responder rápido; 500 faz a Meta tentar novamente.
    res.status(500).json({erro:"Erro ao processar webhook."});
  }
}
