import { requireLeadAccess, apiError } from "./_auth.js";
import { checkAndConsumeAI } from "./_usage.js";

export default async function handler(req,res){
  if(req.method!=="POST") return res.status(405).json({erro:"Método não permitido"});

  try{
    const {lead,empresa}=req.body||{};

    if(!lead?.id)
      return res.status(400).json({erro:"Lead não informado."});

    const {admin,lead:dbLead}=await requireLeadAccess(req,lead.id);

    await checkAndConsumeAI(admin,dbLead.company_id,1);

    const p=`Crie uma mensagem curta e natural de follow-up para WhatsApp.
Empresa: ${empresa?.name||""}
Cliente: ${dbLead?.name||""}
Temperatura: ${dbLead?.temperature||""}
Intenção: ${dbLead?.intent||""}
Próximo passo: ${dbLead?.next_step||""}

Não invente informações. Não pressione o cliente. Não prometa disponibilidade, visita, preço ou condição que não esteja confirmada.`;

    const r=await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
      {
        method:"POST",
        headers:{
          "Content-Type":"application/json",
          "x-goog-api-key":process.env.GEMINI_API_KEY
        },
        body:JSON.stringify({contents:[{parts:[{text:p}]}]})
      }
    );

    const d=await r.json();

    if(!r.ok)
      return res.status(500).json({erro:"Erro ao consultar IA."});

    return res.status(200).json({resposta:d?.candidates?.[0]?.content?.parts?.[0]?.text||""});
  }catch(e){
    return apiError(res,e);
  }
}
