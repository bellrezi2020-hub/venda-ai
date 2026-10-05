import { requireLeadAccess, apiError } from "./_auth.js";

export default async function handler(req,res){
 if(req.method!=="POST")return res.status(405).json({erro:"Método não permitido"});
 try{
  const {lead,empresa,imoveis,mensagens}=req.body||{};
  if(!lead?.id)return res.status(400).json({erro:"Lead não informado."});
  await requireLeadAccess(req,lead.id);
  const hist=(mensagens||[]).map(m=>`${m.role==="assistant"?"ASSISTENTE":"CLIENTE"}: ${m.content}`).join("\n");
  const cat=(imoveis||[]).map(i=>`${i.title}|${i.purpose}|R$${i.price}|${i.neighborhood||""}|${i.city||""}|${i.bedrooms||0} quartos|garagem ${i.garage?"sim":"não"}`).join("\n")||"Sem imóveis.";
  const prompt=`Continue uma conversa imobiliária. Empresa: ${empresa?.name||""}. Lead: ${lead?.name||""}. Temperatura: ${lead?.temperature||""}. Intenção: ${lead?.intent||""}. Catálogo real:\n${cat}\nHistórico:\n${hist}\nRegras: status só Quente/Morno/Frio. Não invente nada. Faça no máximo uma pergunta por vez. Se cliente pedir visita, solicitouVisita=true e diga apenas que a preferência será encaminhada para confirmação; nunca diga que está confirmado. Retorne JSON: status,intencao,resposta,proximoPasso,solicitouVisita,imoveisCompativeis.`;
  const r=await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",{method:"POST",headers:{"Content-Type":"application/json","x-goog-api-key":process.env.GEMINI_API_KEY},body:JSON.stringify({contents:[{parts:[{text:prompt}]}],generationConfig:{responseMimeType:"application/json",responseSchema:{type:"OBJECT",properties:{status:{type:"STRING",enum:["Quente","Morno","Frio"]},intencao:{type:"STRING"},resposta:{type:"STRING"},proximoPasso:{type:"STRING"},solicitouVisita:{type:"BOOLEAN"},imoveisCompativeis:{type:"ARRAY",items:{type:"OBJECT",properties:{titulo:{type:"STRING"},motivo:{type:"STRING"}},required:["titulo","motivo"]}}},required:["status","intencao","resposta","proximoPasso","solicitouVisita","imoveisCompativeis"]}}})});
  const d=await r.json();if(!r.ok)return res.status(500).json({erro:"Erro ao consultar IA."});const a=JSON.parse(d.candidates[0].content.parts[0].text);
  if(a.solicitouVisita){const t=a.imoveisCompativeis?.[0]?.titulo;a.resposta=`Perfeito, ${lead?.name||"Cliente"}! Vou encaminhar sua preferência de dia e horário para a imobiliária confirmar a disponibilidade${t?` da visita ao imóvel ${t}`:""}. Assim que houver confirmação, você recebe os detalhes.`;a.proximoPasso="Confirmar internamente a disponibilidade da visita e depois retornar ao cliente."}
  return res.status(200).json(a);
 }catch(e){return apiError(res,e)}
}
