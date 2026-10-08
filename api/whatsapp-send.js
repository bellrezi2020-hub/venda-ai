import { requireLeadAccess, apiError } from "./_auth.js";

export default async function handler(req,res){
  if(req.method !== "POST")
    return res.status(405).json({erro:"Método não permitido"});

  try{
    const {leadId,text} = req.body || {};
    const message = String(text||"").trim();

    if(!leadId) return res.status(400).json({erro:"Lead não informado."});
    if(!message) return res.status(400).json({erro:"Mensagem vazia."});
    if(message.length > 4000)
      return res.status(400).json({erro:"Mensagem muito longa."});

    const {admin,lead} = await requireLeadAccess(req,leadId);

    const to = String(lead.whatsapp_contact_id || lead.phone || "")
      .replace(/\D/g,"");

    if(!to)
      return res.status(400).json({erro:"Este lead não possui número de WhatsApp."});

    const {data:connection,error:connectionError} = await admin
      .from("whatsapp_connections")
      .select("*")
      .eq("company_id",lead.company_id)
      .eq("enabled",true)
      .maybeSingle();

    if(connectionError) throw connectionError;

    if(!connection)
      return res.status(400).json({erro:"WhatsApp ainda não está ativado para esta empresa."});

    const token = process.env.WHATSAPP_ACCESS_TOKEN;
    const graphVersion = process.env.META_GRAPH_VERSION;

    if(!token || !graphVersion)
      return res.status(500).json({erro:"Credenciais do WhatsApp ainda não configuradas na Vercel."});

    const r = await fetch(
      `https://graph.facebook.com/${encodeURIComponent(graphVersion)}/${encodeURIComponent(connection.phone_number_id)}/messages`,
      {
        method:"POST",
        headers:{
          "Authorization":`Bearer ${token}`,
          "Content-Type":"application/json"
        },
        body:JSON.stringify({
          messaging_product:"whatsapp",
          recipient_type:"individual",
          to,
          type:"text",
          text:{preview_url:false,body:message}
        })
      }
    );

    const d = await r.json();

    if(!r.ok){
      console.error("WhatsApp send error",d);
      return res.status(502).json({erro:"A Meta recusou o envio da mensagem."});
    }

    const externalId = d?.messages?.[0]?.id || null;

    const {error:insertError} = await admin
      .from("messages")
      .insert({
        lead_id:lead.id,
        role:"assistant",
        content:message,
        channel:"whatsapp",
        direction:"outbound",
        external_id:externalId,
        delivery_status:"sent"
      });

    if(insertError) throw insertError;

    await admin
      .from("leads")
      .update({last_activity_at:new Date().toISOString()})
      .eq("id",lead.id);

    return res.status(200).json({ok:true,messageId:externalId});
  }catch(e){
    return apiError(res,e);
  }
}
