export default async function handler(req,res){
 if(req.method!=="POST")return res.status(405).json({erro:"Método não permitido"});
 try{
  const {lead,empresa,imoveis,mensagens}=req.body;
  const historico=(mensagens||[]).map(m=>`${m.role==="assistant"?"ASSISTENTE":"CLIENTE"}: ${m.content}`).join("\n");
  const catalogo=(imoveis||[]).map(i=>`${i.title} | ${i.purpose} | R$ ${i.price} | ${i.neighborhood||""} ${i.city||""} | ${i.bedrooms||0} quartos | garagem ${i.garage?"sim":"não"}`).join("\n")||"Sem imóveis cadastrados.";
  const prompt=`Você continua uma conversa de qualificação imobiliária.
Empresa: ${empresa?.name||""}. Região: ${empresa?.region||""}.
Lead: ${lead?.name||""}. Intenção atual: ${lead?.intent||""}. Temperatura atual: ${lead?.temperature||""}.
Catálogo real:
${catalogo}

Histórico:
${historico}

Responda à última mensagem do cliente de forma natural. Faça no máximo uma pergunta por vez, avance em direção a orçamento, região, tipo, quartos, garagem, forma de pagamento e agendamento quando fizer sentido. Não invente dados.

Retorne JSON com status, intencao, resposta, proximoPasso e imoveisCompativeis.`;
  const r=await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",{method:"POST",headers:{"Content-Type":"application/json","x-goog-api-key":process.env.GEMINI_API_KEY},body:JSON.stringify({contents:[{parts:[{text:prompt}]}],generationConfig:{responseMimeType:"application/json",responseSchema:{type:"OBJECT",properties:{status:{type:"STRING"},intencao:{type:"STRING"},resposta:{type:"STRING"},proximoPasso:{type:"STRING"},imoveisCompativeis:{type:"ARRAY",items:{type:"OBJECT",properties:{titulo:{type:"STRING"},motivo:{type:"STRING"}},required:["titulo","motivo"]}}},required:["status","intencao","resposta","proximoPasso","imoveisCompativeis"]}}})});
  const d=await r.json();if(!r.ok)return res.status(500).json({erro:"Erro ao consultar a IA."});
  res.status(200).json(JSON.parse(d.candidates[0].content.parts[0].text));
 }catch(e){res.status(500).json({erro:"Erro interno."})}
}
